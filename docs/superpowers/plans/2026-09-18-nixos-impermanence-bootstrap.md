# NixOS Impermanence Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a generic `build-installer --host HOST` flow that builds a host-specific ISO from the exact public `main` Git revision, generates fresh facter hardware state at install time, provisions one fixed Disko/impermanence layout, installs the final system with a persistent administrator password, and powers off for manual media removal.

**Architecture:** NixOS final configurations require `facter.json` and have no legacy hardware fallback. Installer package generation uses only normalized host metadata, so ISO construction does not evaluate the final host. Runtime uses one clean raw Git checkout, one final remote/disk acceptance barrier, one fixed storage layout, direct NixOS password policy, and one full lifecycle E2E.

**Tech Stack:** NixOS/nixpkgs, flake-parts, Disko, nixos-facter, preservation, Nushell, Git, systemd-boot, NixOS VM tests.

**Spec:** `docs/superpowers/specs/2026-09-18-nixos-impermanence-bootstrap-design.md`

## Global Constraints

- `build-installer --host HOST` remains generic for declared NixOS hosts.
- Canonical installer origin is `https://github.com/sugiura-hiromiti/dotfiles.git`.
- Builder identity is the revision reported by real Nix for the raw local Git flake.
- Builder accepts that revision only when anonymous HTTPS `main` resolves to the same SHA.
- Local branch name, detached state, local Git remotes, and untracked files are not installer invariants.
- No installer flow uses explicit `path:` flake semantics.
- Final NixOS evaluation requires `facter.json`; there is no `hardware-configuration.nix` fallback.
- Existing legacy-host migration is user-owned and is not implemented by this plan.
- Every installer-side Nix command consuming the cloned flake uses `--no-update-lock-file`.
- Installer code does not use `--no-write-lock-file` and never runs `nix flake update`.
- Storage topology is fixed: GPT + ESP + `dotfiles-system` Btrfs + `@root`, `@nix`, `@persist`.
- Disko target is always `/dev/dotfiles-install-target`.
- There is no storage device option, filesystem UUID identity, configurable partition label, configurable subvolume name, or provisioning enable flag.
- There is no public `ephemeralRoot` feature interface.
- Administrator password policy is declared directly with NixOS built-in user options.
- Disk selection happens once, at the final destructive acceptance barrier.
- The final barrier also re-reads anonymous remote `main` and requires the embedded commit.
- Installer service exclusively owns tty1; tty2 remains available for diagnostics.
- EFI-variable writes remain disabled; boot uses the standard fallback EFI loader.
- Successful installation ends with sync, recursive unmount, and poweroff.
- The implementation builds and tests the ISO but does not boot it on the real machine.

---

## File Structure

```text
nix/
├── installer/
│   ├── config.nix
│   ├── iso.nix
│   ├── script.nix
│   └── install.nu
├── apps/
│   ├── build-installer/
│   │   ├── default.nix
│   │   ├── build.nu
│   │   └── tests/run.sh
│   └── test-installer-e2e/
│       └── default.nix
├── modules/nixos/features/
│   ├── storage/
│   │   ├── layout.nix
│   │   └── provisioning.nix
│   └── impermanence/
│       ├── default.nix
│       ├── impermanence.nix
│       └── preservation.nix
├── tests/
│   ├── installer/
│   │   ├── runtime.nix
│   │   └── e2e.nix
│   └── nixos/
│       ├── storage-provisioning.nix
│       ├── impermanence.nix
│       └── preservation.nix
├── configurations/nixos.nix
├── modules/nixos/default.nix
├── flake/apps.nix
├── flake/default.nix
└── checks.nix
```

Delete rather than preserve these historical interfaces/tests:

```text
nix/modules/nixos/features/storage/default.nix
nix/modules/nixos/features/impermanence/ephemeral-root.nix
nix/tests/nixos/ephemeral-root.nix
nix/tests/nixos/storage-provisioning-vm.nix
nix/tests/nixos/impermanence-vm.nix
```

Do not create a bootstrap-credentials module, installer host-metadata flake
output, default-target helper used only by the installer, migration selector,
or additional storage abstraction.

---

### Task 1: Collapse the Final NixOS State to Facter + Fixed Storage + Direct Credentials

**Files:**

- Create: `nix/modules/nixos/features/storage/layout.nix`
- Modify: `nix/modules/nixos/features/storage/provisioning.nix`
- Delete: `nix/modules/nixos/features/storage/default.nix`
- Modify: `nix/modules/nixos/features/impermanence/impermanence.nix`
- Modify: `nix/modules/nixos/features/impermanence/default.nix`
- Delete: `nix/modules/nixos/features/impermanence/ephemeral-root.nix`
- Modify: `nix/modules/nixos/default.nix`
- Modify: `nix/configurations/nixos.nix`
- Modify: `nix/flake/default.nix`
- Modify: `nix/tests/nixos/storage-provisioning.nix`
- Modify: `nix/tests/nixos/impermanence.nix`
- Modify: `nix/checks.nix`

**Precondition:**

- The user's current legacy NixOS host migration to `facter.json` is complete before this task is executed.
- If a currently evaluated NixOS host still depends on `hardware-configuration.nix`, stop and report that precondition instead of adding compatibility code.

**Interfaces:**

- Internal fixed layout from `storage/layout.nix`:
  - `partitionLabel = "dotfiles-system"`
  - `rootSubvolume = "@root"`
  - `nixSubvolume = "@nix"`
  - `persistSubvolume = "@persist"`
  - `installDisk = "/dev/dotfiles-install-target"`
- Final NixOS configuration directly owns:
  - `hardware.facter.reportPath`
  - `users.mutableUsers = false`
  - `users.users.<primary>.hashedPasswordFile`
  - preservation/impermanence enablement.

- [ ] **Step 1: Rewrite the structural tests first**

In `nix/tests/nixos/storage-provisioning.nix`, assert only the fixed topology:

```nix
assert disk.device == "/dev/dotfiles-install-target";
assert disk.content.type == "gpt";
assert disk.content.partitions.ESP.content.mountpoint == "/boot";
assert disk.content.partitions.system.label == "dotfiles-system";
assert disk.content.partitions.system.content.type == "btrfs";
assert disk.content.partitions.system.content.subvolumes ? "@root";
assert disk.content.partitions.system.content.subvolumes ? "@nix";
assert disk.content.partitions.system.content.subvolumes ? "@persist";
```

Remove all filesystem-UUID, configurable-label, configurable-subvolume, and enable-option fixtures.

In `nix/tests/nixos/impermanence.nix`, assert:

```nix
assert system.config.dotfiles.features.impermanence.enable;
assert system.config.fileSystems."/nix".neededForBoot;
assert system.config.fileSystems."/persist".neededForBoot;
```

Also inspect the initrd service configuration to prove root reset uses
`PARTLABEL=dotfiles-system`, `@root`, and fails before deletion unless
exactly one matching partition is found.

- [ ] **Step 2: Run the focused checks and observe failure**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).storage-provisioning
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).impermanence
```

Expected: FAIL because the current modules still expose UUID/configurable
storage and the separate ephemeral-root interface.

- [ ] **Step 3: Add one internal fixed layout**

Create `nix/modules/nixos/features/storage/layout.nix`:

```nix
{
  partitionLabel = "dotfiles-system";
  rootSubvolume = "@root";
  nixSubvolume = "@nix";
  persistSubvolume = "@persist";
  installDisk = "/dev/dotfiles-install-target";
}
```

This is an internal constant set, not a NixOS option API.

- [ ] **Step 4: Reduce Disko provisioning to the fixed layout**

Rewrite `storage/provisioning.nix` so importing it always declares:

```text
/dev/dotfiles-install-target
  GPT
  ESP 512M EF00 -> vfat /boot
  system label dotfiles-system -> btrfs
    @root    -> /
    @nix     -> /nix
    @persist -> /persist
```

Remove:

- `filesystemUuid`;
- `dotfiles.features.storage.*` options;
- Btrfs `-U` arguments;
- `provisioning.enable`;
- configurable disk/label/subvolume values.

Delete `storage/default.nix`.

- [ ] **Step 5: Fold root reset directly into impermanence**

Move the initrd mount/delete/create behavior from `ephemeral-root.nix` into
`impermanence.nix`.

Before mounting/deleting `@root`, execute the Nix-store path to `blkid`:

```text
blkid -t PARTLABEL=dotfiles-system -o device
```

Normalize unique non-empty results and require exactly one block device.

Mount that device's Btrfs top level, delete `@root` when present, recreate it,
then permit `sysroot.mount`.

Delete the entire public `dotfiles.features.ephemeralRoot` option family and
delete `ephemeral-root.nix`.

Update `impermanence/default.nix` to import only `impermanence.nix` and
`preservation.nix`.

- [ ] **Step 6: Remove the obsolete global storage module import**

Remove `./features/storage` from `nix/modules/nixos/default.nix`.

The fixed Disko provisioning module is imported only by the final NixOS
constructor.

- [ ] **Step 7: Harden `configurations/nixos.nix` to require facter**

Pass `disko` into the NixOS constructor from `nix/flake/default.nix`.

For each NixOS target derive:

```nix
hostDir = ../profiles/hosts + "/${config.host}";
facterPath = hostDir + "/facter.json";
```

Require `builtins.pathExists facterPath`; otherwise throw a message stating
that the host requires committed facter data and there is no legacy fallback.

Always include:

```nix
{ hardware.facter.reportPath = facterPath; }
(import ../modules/nixos/features/storage/provisioning.nix { inherit disko; })
{
  dotfiles.features = {
    preservation.enable = true;
    impermanence.enable = true;
  };

  users.mutableUsers = false;
  users.users.${config.primaryAccountName}.hashedPasswordFile =
    "/persist/etc/dotfiles/password-${config.primaryAccountName}.hash";
}
```

Do not inspect or import `hardware-configuration.nix`.

- [ ] **Step 8: Remove the obsolete VM checks**

Delete:

```text
nix/tests/nixos/ephemeral-root.nix
nix/tests/nixos/storage-provisioning-vm.nix
nix/tests/nixos/impermanence-vm.nix
```

Remove their entries from `nix/checks.nix`.

Keep the cheap structural storage/impermanence checks and the existing
preservation check. Full boot/install behavior moves to Task 4's single E2E.

- [ ] **Step 9: Run deterministic checks**

```bash
nix flake check -L
```

Expected: PASS with the user's facter migration present.

- [ ] **Step 10: Commit**

```bash
git add -A nix/modules/nixos nix/configurations/nixos.nix nix/flake/default.nix nix/tests/nixos nix/checks.nix
git commit -m "refactor: collapse nixos bootstrap state"
```

---

### Task 2: Implement One Raw-Git Installer Transaction

**Files:**

- Create: `nix/installer/install.nu`
- Create: `nix/installer/script.nix`
- Create: `nix/tests/installer/runtime.nix`
- Modify: `nix/checks.nix`

**Interfaces:**

- `mkInstallerScript { host; target; primaryAccount; origin; commit; efiArch; }`
- Runtime checkout: `/run/dotfiles-installer/repo`.
- Destructive alias: `/dev/dotfiles-install-target`.
- Exactly one acceptance barrier immediately before alias creation/Disko.

- [ ] **Step 1: Write transaction tests before the script**

Use fake `git`, `nix`, Disko, and `nixos-install` executables.

Cover:

1. clone HEAD differs from embedded commit -> abort;
2. final anonymous `main` SHA differs from embedded commit -> abort before
   alias creation/Disko;
3. zero eligible disks at the final barrier -> abort;
4. two eligible disks at the final barrier -> abort;
5. exactly one eligible disk -> select it;
6. every runtime `nix eval`, `nix build`, and `nixos-install --flake`
   command contains `--no-update-lock-file`;
7. no command contains `--no-write-lock-file`, `nix flake update`, or
   `path:`.

The remote-race fixture returns commit C from clone/initial checkout and commit
D from the final `ls-remote`; Disko must remain uncalled.

- [ ] **Step 2: Implement the clone as the initial commit check**

Use:

```bash
git clone --branch main --single-branch "$origin" "$repo"
```

Then require:

```bash
git -C "$repo" rev-parse HEAD == "$commit"
```

Do not run a separate initial fetch, `git switch -C`, or
`branch --set-upstream-to`; clone already creates the local tracking branch.

- [ ] **Step 3: Capture and hash the administrator password**

Prompt twice with echo disabled. Reject empty/mismatched input.

Pipe plaintext through the Nix-provided yescrypt-capable `mkpasswd` using
stdin. Keep only the resulting hash in memory.

- [ ] **Step 4: Generate and commit facter**

Run:

```text
nixos-facter -o nix/profiles/hosts/<host>/facter.json
git add nix/profiles/hosts/<host>/facter.json
```

If the index differs, commit exactly that path with:

```text
bootstrap: record hardware facts
```

and a fixed installer-local author identity.

If it does not differ, create no empty commit.

The checkout must be clean after this step.

- [ ] **Step 5: Evaluate the final target from the raw Git checkout**

Use raw absolute checkout references such as:

```text
/run/dotfiles-installer/repo#nixosConfigurations.<target>...
```

Never prefix the checkout with `path:`.

With `--no-update-lock-file`, evaluate:

```text
config.system.build.toplevel.drvPath
config.users.users.<primary>.home
config.users.users.<primary>.uid
config.users.users.<primary>.group
config.users.groups.<group>.gid
config.users.users.<primary>.hashedPasswordFile
```

Reject null/non-integer UID or GID and an empty group/hash-file path.

Evaluating the toplevel drvPath is the pre-destructive full configuration
validation; do not realize that toplevel yet.

- [ ] **Step 6: Realize only the Disko script**

Build:

```text
nixosConfigurations.<target>.config.system.build.diskoScript
```

from the same raw checkout with `--no-update-lock-file --no-link
--print-out-paths`.

- [ ] **Step 7: Implement the single destructive acceptance barrier**

First read the public remote directly:

```bash
git ls-remote "$origin" refs/heads/main
```

using the same anonymous/no-prompt Git environment as the builder. Require one
SHA and require it to equal the embedded commit.

Then run:

```text
lsblk --json --output PATH,TYPE,RM,HOTPLUG
```

and require exactly one whole disk where `RM=0` and `HOTPLUG=0`.

Only after both checks succeed:

```bash
ln -sfn "$disk" /dev/dotfiles-install-target
```

There is no earlier disk scan and no cross-time disk identity.

- [ ] **Step 8: Provision and materialize the secret**

Run the Disko script and require `/mnt`, `/mnt/boot`, `/mnt/nix`, and
`/mnt/persist` to be mountpoints.

Write the password hash to:

```text
/mnt + <evaluated hashedPasswordFile>
```

with parent mode `0700` and file mode `0600`.

- [ ] **Step 9: Install from the same raw checkout**

Run:

```bash
nixos-install \
  --root /mnt \
  --flake "$repo#$target" \
  --no-update-lock-file \
  --no-channel-copy \
  --no-root-password
```

Do not add `--no-write-lock-file`.

- [ ] **Step 10: Verify fallback boot and persist the checkout**

Require:

```text
/mnt/boot/EFI/BOOT/BOOT<UPPERCASE_EFI_ARCH>.EFI
```

Copy the complete already-validated checkout including `.git` to:

```text
/mnt/persist + <evaluated home> + /dotfiles
```

and recursively chown it to the evaluated UID:GID.

Do not add redundant post-copy Git branch/origin/revision verification.

- [ ] **Step 11: Finish safely**

Run `sync`, recursively unmount `/mnt`, verify it is no longer mounted, then
invoke `systemctl poweroff`.

Any earlier failure exits non-zero and leaves the installer running.

- [ ] **Step 12: Run tests and commit**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).installer-runtime
nix flake check -L
git add nix/installer/install.nu nix/installer/script.nix nix/tests/installer/runtime.nix nix/checks.nix
git commit -m "feat: implement raw-git nixos installer"
```

---

### Task 3: Build Generic Host ISOs From Public-Main Git Identity

**Files:**

- Create: `nix/installer/config.nix`
- Create: `nix/installer/iso.nix`
- Create: `nix/apps/build-installer/default.nix`
- Create: `nix/apps/build-installer/build.nu`
- Create: `nix/apps/build-installer/tests/run.sh`
- Modify: `nix/flake/apps.nix`
- Modify: `nix/flake/default.nix`
- Modify: `nix/checks.nix`

**Interfaces:**

- `installer/config.nix`: `origin = "https://github.com/sugiura-hiromiti/dotfiles.git"`
- Packages: `packages.installer-<host>` for every declared NixOS host on its
  matching system.
- App: `nix run .#build-installer -- --host HOST`.
- Output link: `result/installer-HOST`.

- [ ] **Step 1: Write the builder tests**

Use a temporary clean Git repository for real Nix metadata behavior and fake
only the network-facing `git ls-remote` call.

Prove:

- clean raw Git flake -> `metadata.revision == git HEAD`;
- tracked/staged modification -> no acceptable concrete revision;
- untracked file -> revision remains HEAD and does not block the builder;
- remote-main SHA different from metadata revision -> reject;
- matching remote-main SHA -> build command is
  `nix build <raw-repo>#installer-<host>`;
- no builder command contains `path:`;
- no check depends on current branch, detached state, local `origin`, or
  local remote-tracking refs.

- [ ] **Step 2: Declare the canonical origin once**

Create:

```nix
{
  origin = "https://github.com/sugiura-hiromiti/dotfiles.git";
}
```

in `nix/installer/config.nix`.

Do not publish an installer-specific host metadata flake output.

- [ ] **Step 3: Generate installer packages directly from normalized host metadata**

In the flake wiring, select hosts where:

```nix
host.systemTargetKind == "nixos"
```

For each such host derive the target name directly with existing
`targetNames.mkSystemTargetName` using:

```nix
host.targetHost
host.runtime.defaultTheme
host.runtime.defaultSession
host.runtime.targetAxes
```

Pass `host.primaryAccountName` directly to the ISO constructor.

Do not export `runtime.mkRuntimeContext`, add `mkDefaultHostTargetConfig`,
or create `flake.installer.hosts.*`.

- [ ] **Step 4: Construct the ISO without final-host evaluation**

`nix/installer/iso.nix` receives:

```nix
{
  host,
  target,
  primaryAccount,
  origin,
  commit,
}
```

and derives EFI architecture from the ISO platform.

Use:

```nix
commit =
  if self ? rev then self.rev
  else throw "installer ISO requires a clean Git flake revision";
```

ISO construction must not reference `nixosConfigurations.<target>`, so it can
bootstrap a newly declared host before that host has facter data.

- [ ] **Step 5: Give tty1 exclusively to the installer**

Override the minimal installer profile so tty1 is not pulled into
`getty.target` and tty2 remains diagnostic:

```nix
systemd.targets.getty.wants = lib.mkForce [ "autovt@tty2.service" ];
```

Configure `dotfiles-installer.service` with:

```nix
wantedBy = [ "multi-user.target" ];
after = [ "network-online.target" ];
wants = [ "network-online.target" ];
conflicts = [
  "getty@tty1.service"
  "autovt@tty1.service"
];

serviceConfig = {
  Type = "oneshot";
  StandardInput = "tty-force";
  StandardOutput = "tty";
  StandardError = "tty";
  TTYPath = "/dev/tty1";
  TTYReset = true;
};
```

- [ ] **Step 6: Implement the builder around one identity comparison**

Resolve the repository root and run real Nix:

```bash
nix flake metadata --json "$repo" --no-update-lock-file
```

Require a concrete `revision`.

Read public `main` anonymously:

```bash
HOME="$empty_home" \
XDG_CONFIG_HOME="$empty_home" \
GIT_CONFIG_NOSYSTEM=1 \
GIT_TERMINAL_PROMPT=0 \
git -c credential.helper= \
  ls-remote "$origin" refs/heads/main
```

Unset `GIT_ASKPASS` and `SSH_ASKPASS`.

Require exactly one SHA and:

```text
metadata.revision == remote main SHA
```

Then build:

```text
nix build <raw-repository>#installer-<host>
  --out-link <repository>/result/installer-<host>
```

Do not inspect branch name, detached state, `git status`, local `origin`, or
`origin/main`.

- [ ] **Step 7: Add deterministic ISO wiring checks**

Assert:

- package generation exists for every NixOS host and not Darwin-only hosts;
- target name uses normalized default theme/session;
- primary account comes directly from host normalization;
- installer service owns tty1 and tty1 getty/autovt is not wanted;
- ISO constructor does not depend on final NixOS configuration evaluation.

- [ ] **Step 8: Run checks and commit**

```bash
nix flake check -L
nix run .#build-installer -- --help
git add nix/installer/config.nix nix/installer/iso.nix nix/apps/build-installer nix/flake/apps.nix nix/flake/default.nix nix/checks.nix
git commit -m "feat: build generic nixos installer iso"
```

---

### Task 4: Replace Intermediate VM Layers With One Installer Lifecycle E2E

**Files:**

- Create: `nix/tests/installer/e2e.nix`
- Create: `nix/apps/test-installer-e2e/default.nix`
- Modify: `nix/flake/apps.nix`
- Modify: `nix/checks.nix`
- Modify: `README.org`
- Modify: `flake.nix` comments

**Interfaces:**

- Manual networked test: `nix run .#test-installer-e2e`.
- Networked lifecycle test is not executed inside the Nix build sandbox.

- [ ] **Step 1: Expose the E2E driver as a runtime app**

Build the NixOS test driver deterministically, but execute
`driverInteractive/bin/nixos-test-driver --no-interactive` from the app so
the lifecycle test has normal network access.

Do not add another VM integration layer.

- [ ] **Step 2: Model only the supported machine**

The VM has:

- UEFI;
- actual generated installer ISO as CD media;
- exactly one writable non-removable internal disk;
- network;
- no second `dotfiles-system` disk.

- [ ] **Step 3: Verify the real ISO console contract**

Boot the ISO and wait for the installer password prompt.

While it is active, assert:

```text
dotfiles-installer.service = active
getty@tty1.service         = inactive/non-running
autovt@tty1.service        = inactive/non-running
```

Confirm tty2 remains usable for diagnostics.

- [ ] **Step 4: Run the complete successful install**

Use the declared anonymous HTTPS repository and the exact public `main`
revision accepted by the builder.

Feed a deterministic test password and verify:

1. clone creates local `main`;
2. cloned HEAD equals embedded commit;
3. facter is generated and only conditionally committed;
4. final target evaluates from the raw Git checkout with
   `--no-update-lock-file`;
5. final anonymous remote-main check equals the embedded commit;
6. final block-device scan sees exactly one eligible disk;
7. Disko creates the fixed `dotfiles-system` / `@root` / `@nix` /
   `@persist` layout;
8. password hash is outside Git/store under `/persist`;
9. target-store `nixos-install` succeeds;
10. fallback EFI loader exists;
11. checkout is copied with evaluated UID/GID;
12. installer powers off.

The remote-race failure path remains a deterministic Task 2 transaction test;
do not add a controllable Git-server subsystem solely for E2E.

- [ ] **Step 5: Boot the installed disk with ISO media removed**

Restart the VM without the installer CD.

Require:

```text
/        -> @root
/nix     -> @nix
/persist -> @persist
```

and `multi-user.target`.

- [ ] **Step 6: Verify authentication and impermanence**

With the deterministic fixture password:

- local password authentication succeeds;
- `sudo` authentication succeeds.

Create:

- a disposable root marker;
- one marker covered by the preservation policy;
- one file in the persisted dotfiles checkout.

Reboot and prove:

- disposable root state vanished;
- preserved state survived;
- checkout survived;
- `@root` was recreated.

- [ ] **Step 7: Keep deterministic checks cheap**

`nix flake check` should contain structural/unit checks only plus construction
of the E2E driver closure where useful. It must not execute the networked
lifecycle.

Verify the obsolete intermediate VM checks from Task 1 are absent.

- [ ] **Step 8: Update operator documentation**

Update `README.org` so the bootstrap path is:

```text
1. declare host metadata
2. nix run .#build-installer -- --host HOST
3. write/attach result/installer-HOST
4. boot installer
5. enter password
6. wait for poweroff
7. remove/eject installer media
8. power on
```

Document:

- final NixOS configurations use facter only;
- no legacy hardware fallback;
- raw Git-flake semantics are used by installer flows;
- `--no-update-lock-file` is the installer freeze control;
- the fixed storage topology and unsupported cases.

For commands operating directly on the user's Git checkout, replace historical
`path:.#...` examples with ordinary Git-flake references such as `.#...`.
Apply the same documentation cleanup to the usage comments at the top of
`flake.nix`.

Do not change the update implementation's private temporary `path:` flake:
that copy is intentionally a non-Git snapshot and is a legitimate use of
`path:`.

- [ ] **Step 9: Run all checks**

```bash
nix flake check -L
nix run .#test-installer-e2e
```

Expected: PASS.

If required KVM/virtualization support is unavailable, report that environmental
limitation; do not add a slower fallback solely to make the E2E pass.

- [ ] **Step 10: Build the real ISO artifact but do not boot it**

From a revision that the builder verifies equals public `main`:

```bash
nix run .#build-installer -- --host aarch64-linux-a
test -e result/installer-aarch64-linux-a
```

Verify the built ISO embeds the accepted revision.

**STOP HERE. Do not boot the ISO on the real machine as part of this plan.**

- [ ] **Step 11: Commit**

```bash
git add nix/tests/installer/e2e.nix nix/apps/test-installer-e2e nix/flake/apps.nix nix/checks.nix README.org flake.nix
git commit -m "test: cover installer lifecycle end to end"
```

---

## Plan Self-Review Checklist

- [ ] Generic `build-installer --host HOST` is retained.
- [ ] No legacy hardware selector or `hardware-configuration.nix` fallback.
- [ ] No explicit `path:` flake reference in installer builder/runtime.
- [ ] No `--no-write-lock-file` in installer commands.
- [ ] No builder branch/detached/local-origin/untracked-file policy.
- [ ] No installer-specific host metadata flake output.
- [ ] No installer-only default-target/runtime-context abstraction.
- [ ] No bootstrap-credentials module or duplicate hash-path option.
- [ ] No initial disk preflight.
- [ ] No post-copy Git revalidation.
- [ ] No filesystem UUID or public storage device option.
- [ ] No configurable partition label or subvolume names.
- [ ] No public ephemeral-root option API.
- [ ] No storage provisioning enable flag.
- [ ] No redundant storage/ephemeral-root/impermanence VM stack beside the lifecycle E2E.
- [ ] Final remote-main + disk check is the single destructive acceptance barrier.
- [ ] Real-machine boot remains outside implementation scope.
