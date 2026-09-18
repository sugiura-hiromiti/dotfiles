# NixOS Impermanence Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement generic `build-installer --host HOST` from the current filtered dotfiles filesystem snapshot, generate fresh facter data at install time, provision one fixed Disko/impermanence layout, install the final NixOS configuration, persist the resulting dotfiles tree, and power off for manual media removal.

**Architecture:** Installer correctness is independent of Git history. Operator commands use explicit `path:.`; a shared `nix-gitignore` filter converts the current filesystem tree into an immutable Nix store snapshot while excluding ignored local state. Final NixOS configurations exist only for hosts with facter data; the ISO embeds the snapshot and at runtime copies it writable, adds facter, evaluates it with `path:`, performs one disk acceptance barrier, installs, and persists that same tree.

**Tech Stack:** NixOS/nixpkgs, flake-parts, Disko, nixos-facter, preservation, Nushell, nix-gitignore, systemd-boot, NixOS VM tests.

**Spec:** `docs/superpowers/specs/2026-09-18-nixos-impermanence-bootstrap-design.md`

## Global Constraints

- Generic command: `nix run path:.#build-installer -- --host HOST`.
- Git history, commits, branches, remotes, index state, and cleanliness are outside installer correctness.
- Shared source policy: `pkgs.nix-gitignore.gitignoreSource [ ] self.outPath`.
- The root `.gitignore` is a source-filter policy; ignored local state and `.git` do not enter snapshots.
- Final NixOS configurations require facter; there is no legacy hardware fallback.
- Facter-less declared NixOS hosts still have installer packages.
- Installer-side flake operations use `--no-update-lock-file`, not `--no-write-lock-file`.
- Fixed storage: GPT + ESP + `dotfiles-system` Btrfs + `@root`, `@nix`, `@persist`.
- Disko target alias: `/dev/dotfiles-install-target`.
- No public storage device/UUID/label/subvolume/provisioning option surface.
- Root reset is internal to impermanence.
- Password policy is expressed directly with NixOS user options.
- Exactly one disk scan is correctness-critical: the final destructive barrier.
- Installer runtime dependencies are explicit Nix store paths.
- tty1 installer units are fail-closed against getty/autovt recreation; tty2 remains diagnostic.
- `boot.loader.efi.canTouchEfiVariables = false`.
- Installed dotfiles are a plain filesystem snapshot; Git metadata is not required.
- `path:.#update` must work without a Git repository.
- Keep one deterministic impermanence boot/reboot VM plus one full installer lifecycle E2E.
- Implementation does not boot the installer on the user's real machine.

---

## File Structure

```text
nix/
├── lib/
│   └── source.nix
├── installer/
│   ├── iso.nix
│   ├── script.nix
│   └── install.nu
├── apps/
│   ├── build-installer/
│   │   ├── default.nix
│   │   ├── build.nu
│   │   └── tests/run.sh
│   ├── update/
│   │   ├── operation.nu
│   │   ├── script.nix
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
│       ├── impermanence-vm.nix
│       └── preservation.nix
├── flake/
│   ├── configurations.nix
│   ├── installer.nix
│   ├── apps.nix
│   ├── checks.nix
│   └── default.nix
├── configurations/nixos.nix
├── modules/nixos/default.nix
└── checks.nix
```

Delete rather than preserve these historical layers:

```text
nix/modules/nixos/features/storage/default.nix
nix/modules/nixos/features/impermanence/ephemeral-root.nix
nix/tests/nixos/ephemeral-root.nix
nix/tests/nixos/storage-provisioning-vm.nix
```

Keep exactly one behavioral impermanence VM: `nix/tests/nixos/impermanence-vm.nix`.

---

### Task 1: Collapse Final NixOS State and Gate It on Facter

**Files:**
- Create: `nix/modules/nixos/features/storage/layout.nix`
- Modify: `nix/modules/nixos/features/storage/provisioning.nix`
- Delete: `nix/modules/nixos/features/storage/default.nix`
- Modify: `nix/modules/nixos/features/impermanence/impermanence.nix`
- Modify: `nix/modules/nixos/features/impermanence/default.nix`
- Delete: `nix/modules/nixos/features/impermanence/ephemeral-root.nix`
- Modify: `nix/modules/nixos/default.nix`
- Modify: `nix/configurations/nixos.nix`
- Modify: `nix/flake/configurations.nix`
- Modify: `nix/flake/checks.nix`
- Modify: `nix/flake/default.nix`
- Modify: `nix/tests/nixos/storage-provisioning.nix`
- Modify: `nix/tests/nixos/impermanence.nix`
- Modify: `nix/tests/nixos/impermanence-vm.nix`
- Delete: `nix/tests/nixos/ephemeral-root.nix`
- Delete: `nix/tests/nixos/storage-provisioning-vm.nix`
- Modify: `nix/checks.nix`

**Precondition:**
- Before executing this task against the current production host, the user has migrated `aarch64-linux-a` to a valid `facter.json`.
- Do not add any `hardware-configuration.nix` fallback if that precondition is false.

**Interfaces:**
- `layout.nix` is internal constants only:
  - `partitionLabel = "dotfiles-system"`
  - `rootSubvolume = "@root"`
  - `nixSubvolume = "@nix"`
  - `persistSubvolume = "@persist"`
  - `installDisk = "/dev/dotfiles-install-target"`
- `nixosHostReady hostName -> bool`: true iff that host has `facter.json`.
- Final exported NixOS configurations always have facter, fixed Disko topology, impermanence, preservation, and direct password-file policy.

- [ ] **Step 1: Rewrite the cheap structural tests**

In `storage-provisioning.nix`, assert exactly:

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

Remove UUID/configurable-device/configurable-label/configurable-subvolume and
enable-option fixtures.

In `impermanence.nix`, assert the initrd configuration:

- uses `PARTLABEL=dotfiles-system`;
- requires exactly one unique block-device match before deleting anything;
- deletes/recreates `@root`;
- marks `/nix` and `/persist` needed for boot.

- [ ] **Step 2: Run focused tests with filesystem semantics**

Use explicit `path:.` so newly created paths are visible before commit:

```bash
nix build -L path:.#checks.$(nix eval --raw --impure --expr builtins.currentSystem).storage-provisioning
nix build -L path:.#checks.$(nix eval --raw --impure --expr builtins.currentSystem).impermanence
```

Expected: FAIL against the current configurable storage/ephemeral-root design.

- [ ] **Step 3: Create one internal storage layout**

Create:

```nix
{
  partitionLabel = "dotfiles-system";
  rootSubvolume = "@root";
  nixSubvolume = "@nix";
  persistSubvolume = "@persist";
  installDisk = "/dev/dotfiles-install-target";
}
```

No NixOS options are introduced for these values.

- [ ] **Step 4: Reduce Disko provisioning to that layout**

Rewrite `storage/provisioning.nix` to always declare:

```text
/dev/dotfiles-install-target
  GPT
  ESP 512M EF00 -> vfat /boot
  dotfiles-system -> btrfs
    @root    -> /
    @nix     -> /nix
    @persist -> /persist
```

Remove `filesystemUuid`, all `dotfiles.features.storage.*` options,
filesystem UUID arguments, configurable disk/label/subvolume fields, and
`provisioning.enable`.

Delete `storage/default.nix`.

- [ ] **Step 5: Fold root reset into impermanence**

Move the initrd behavior from `ephemeral-root.nix` into
`impermanence.nix`.

Run the Nix store path for:

```text
blkid -t PARTLABEL=dotfiles-system -o device
```

Normalize non-empty unique results and require exactly one. Only then mount the
Btrfs top level, delete existing `@root`, recreate `@root`, and allow
`sysroot.mount`.

Delete the public `dotfiles.features.ephemeralRoot` options and
`ephemeral-root.nix`.

- [ ] **Step 6: Require facter in the NixOS constructor**

Pass `disko` into `configurations/nixos.nix`.

Every configuration that is actually constructed imports:

```nix
{ hardware.facter.reportPath = facterPath; }
(import ../modules/nixos/features/storage/provisioning.nix { inherit disko; })
{
  dotfiles.features.preservation.enable = true;
  dotfiles.features.impermanence.enable = true;

  users.mutableUsers = false;
  users.users.${config.primaryAccountName}.hashedPasswordFile =
    "/persist/etc/dotfiles/password-${config.primaryAccountName}.hash";
}
```

There is no legacy conditional inside the constructor.

- [ ] **Step 7: Omit facter-less hosts from final NixOS outputs**

In `nix/flake/default.nix` define the single readiness predicate:

```nix
nixosHostReady =
  hostName:
  builtins.pathExists (../profiles/hosts + "/${hostName}/facter.json");
```

Pass it to `flake/configurations.nix` and `flake/checks.nix`.

In `configurations.nix`, construct `nixosConfigurations` only from NixOS
target entries whose `entry.config.host` passes that predicate.

Home and Darwin outputs are unchanged.

In `flake/checks.nix`, similarly exclude facter-less NixOS entries from
final-system build checks. Installer package generation in Task 3 will use all
declared NixOS hosts and does not use this predicate.

- [ ] **Step 8: Retain one deterministic boot/reboot VM**

Simplify `impermanence-vm.nix` so it tests only:

```text
fixed Disko layout
→ boot
→ disposable root marker + persistent marker
→ reboot
→ disposable marker gone
→ persistent marker survives
→ @root exists again
```

No ISO, networking, Git, source snapshot, facter generation, or password flow
belongs in this test.

Delete `storage-provisioning-vm.nix` and the standalone
`ephemeral-root.nix` test.

- [ ] **Step 9: Run all deterministic checks**

```bash
nix flake check -L path:.
```

Expected: PASS after the user's current-host facter migration.

- [ ] **Step 10: Commit**

```bash
git add -A nix/modules/nixos nix/configurations/nixos.nix nix/flake nix/tests/nixos nix/checks.nix
git commit -m "refactor: collapse nixos bootstrap state"
```

---

### Task 2: Define One Filtered Dotfiles Snapshot and Remove Git From Update

**Files:**
- Create: `nix/lib/source.nix`
- Modify: `nix/flake/apps.nix`
- Modify: `nix/apps/update/operation.nu`
- Modify: `nix/apps/update/script.nix`
- Modify: `nix/apps/update/tests/run.sh`
- Modify: `.gitignore`
- Create: `nix/tests/source-snapshot.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- `mkDotfilesSource { pkgs, root } -> store path`
- Implementation:
  `pkgs.nix-gitignore.gitignoreSource [ ] root`
- Update lock:
  `<runtime dotfiles directory>/.dotfiles-update.lock`
- No Git executable is required by the update app.

- [ ] **Step 1: Add source-policy and update-lock tests**

Add a source fixture containing:

```text
.gitignore: ignored-state/
kept.txt
ignored-state/secret.txt
```

Assert the filtered source contains `kept.txt` and not
`ignored-state/secret.txt`.

The test also asserts the repository root policy excludes
`.dotfiles-update.lock`.

Rewrite update tests to use ordinary directories, not `git init`.

For concurrency, start operation A in one directory, wait until its lock exists,
then start operation B in the **same directory** and require B to fail with:

```text
dependency update is already running
```

Delete the Git-worktree/common-dir concurrency case.

- [ ] **Step 2: Run tests through `path:.` and observe failure**

```bash
nix flake check -L path:.
```

Expected: source helper is missing and update still requires a Git working tree.

- [ ] **Step 3: Implement the shared source filter**

Create `nix/lib/source.nix`:

```nix
{ pkgs, root }:
pkgs.nix-gitignore.gitignoreSource [ ] root
```

This deliberately uses gitignore **syntax/policy**, not Git repository state.

Add:

```text
/.dotfiles-update.lock
```

to the root `.gitignore`.

- [ ] **Step 4: Make the update app consume the filtered snapshot**

In `flake/apps.nix`, derive:

```nix
dotfilesSource = import ../lib/source.nix {
  inherit pkgs;
  root = self.outPath;
};
```

Pass `dotfilesSource` as the update app's `source` rather than raw
`self.outPath`.

When invoked with `nix run path:.#update`, this source therefore represents the
current non-ignored filesystem contents.

- [ ] **Step 5: Remove Git from update locking**

Replace the Git-common-dir lock calculation with:

```text
<repository>/.dotfiles-update.lock
```

Use the existing atomic `mkdir` acquisition/finally-removal behavior.

Remove the `GIT` constant and `pkgs.git` dependency from `script.nix`.

Do not change candidate creation, `nix flake update`, evaluation,
`flake.lock` publication, or activation behavior.

- [ ] **Step 6: Run update/source regressions**

```bash
nix flake check -L path:.
```

Expected: PASS, including update tests in directories with no `.git`.

- [ ] **Step 7: Commit**

```bash
git add .gitignore nix/lib/source.nix nix/flake/apps.nix nix/apps/update nix/tests/source-snapshot.nix nix/checks.nix
git commit -m "refactor: make dotfiles source independent of git"
```

---

### Task 3: Build and Run the Installer From the Embedded Snapshot

**Files:**
- Create: `nix/installer/install.nu`
- Create: `nix/installer/script.nix`
- Create: `nix/installer/iso.nix`
- Create: `nix/flake/installer.nix`
- Create: `nix/apps/build-installer/default.nix`
- Create: `nix/apps/build-installer/build.nu`
- Create: `nix/apps/build-installer/tests/run.sh`
- Create: `nix/tests/installer/runtime.nix`
- Modify: `nix/flake/default.nix`
- Modify: `nix/flake/apps.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- `mkInstallerScript { host; target; primaryAccount; source; efiArch; }`
- `mkInstallerIso { host; target; primaryAccount; source; }`
- Packages: `packages.installer-<host>` for every declared NixOS host on the
  matching system, whether or not facter exists.
- App: `nix run path:.#build-installer -- --host HOST`.
- Result link: `result/installer-HOST`.
- Writable runtime source: `/run/dotfiles-installer/source`.

- [ ] **Step 1: Write runtime transaction tests**

With fake external executables, prove:

1. embedded source is copied to the writable runtime location;
2. facter is written under the selected host path;
3. all final flake references begin with
   `path:/run/dotfiles-installer/source#`;
4. every installer `nix eval`, `nix build`, and `nixos-install` flake
   operation contains `--no-update-lock-file`;
5. no command invokes Git or `nix flake update`;
6. zero eligible disks abort before alias/Disko;
7. multiple eligible disks abort before alias/Disko;
8. exactly one eligible disk creates the alias and permits Disko.

- [ ] **Step 2: Package an explicit installer runtime closure**

`script.nix` embeds store-path constants for at least:

```text
nu              <- pkgs.nushell
nixos-facter    <- pkgs.nixos-facter
nix             <- pkgs.nix
nixos-install   <- pkgs.nixos-install-tools/bin/nixos-install
mkpasswd        <- pkgs.mkpasswd
lsblk/findmnt   <- pkgs.util-linux
cp/chmod/chown/ln/mkdir/rm/sync <- pkgs.coreutils
systemctl       <- pkgs.systemd
```

The script does not rely on these commands being ambient ISO packages.

Add a structural check that the generated script contains the expected store
paths for `nu` and `nixos-facter`.

- [ ] **Step 3: Implement writable snapshot preparation and password input**

At boot:

```text
rm -rf /run/dotfiles-installer/source
cp -a <embedded source> /run/dotfiles-installer/source
chmod -R u+w /run/dotfiles-installer/source
```

Prompt twice with terminal echo suppressed, reject empty/mismatch, hash with
yescrypt via stdin, and retain only the hash.

- [ ] **Step 4: Generate facter directly into the snapshot**

Run:

```text
nixos-facter -o   /run/dotfiles-installer/source/nix/profiles/hosts/<host>/facter.json
```

No Git add/commit/status operation exists.

- [ ] **Step 5: Evaluate the final configuration with `path:`**

Use:

```text
path:/run/dotfiles-installer/source#nixosConfigurations.<target>...
```

with `--no-update-lock-file` to evaluate:

```text
config.system.build.toplevel.drvPath
config.users.users.<primary>.home
config.users.users.<primary>.uid
config.users.users.<primary>.group
config.users.groups.<group>.gid
config.users.users.<primary>.hashedPasswordFile
```

Reject null/non-integer UID or GID and empty group/hash-file paths.

The successful toplevel drvPath evaluation proves fresh facter caused the final
configuration output to exist.

- [ ] **Step 6: Realize only the Disko script before destruction**

Build:

```text
path:/run/dotfiles-installer/source#nixosConfigurations.<target>.config.system.build.diskoScript
```

with:

```text
--no-update-lock-file --no-link --print-out-paths
```

Do not realize the final toplevel before target `/nix` exists.

- [ ] **Step 7: Implement the single destructive disk barrier**

Run:

```text
lsblk --json --output PATH,TYPE,RM,HOTPLUG
```

Require exactly one whole disk with `RM=0`, `HOTPLUG=0`.

Only then:

```bash
ln -sfn "$disk" /dev/dotfiles-install-target
```

There is no earlier disk scan and no source/network/Git acceptance check.

- [ ] **Step 8: Provision, materialize password, and install**

Run the Disko script and require `/mnt`, `/mnt/boot`, `/mnt/nix`, and
`/mnt/persist` to be mountpoints.

Write the hash to `/mnt + <evaluated hashedPasswordFile>`, parent mode
`0700`, file mode `0600`.

Run:

```bash
nixos-install \
  --root /mnt \
  --flake "path:/run/dotfiles-installer/source#$target" \
  --no-update-lock-file \
  --no-channel-copy \
  --no-root-password
```

- [ ] **Step 9: Verify fallback EFI and persist the same source**

Require:

```text
/mnt/boot/EFI/BOOT/BOOT<UPPERCASE_EFI_ARCH>.EFI
```

Copy the writable source tree to:

```text
/mnt/persist + <evaluated home> + /dotfiles
```

and recursively chown to evaluated UID:GID.

Do not copy or synthesize Git metadata.

- [ ] **Step 10: Finish safely**

Run `sync`, recursively unmount `/mnt`, verify it is no longer mounted, then
`systemctl poweroff`.

Earlier failures exit non-zero and leave the installer running.

- [ ] **Step 11: Generate installer packages directly from host metadata**

Create `nix/flake/installer.nix`.

For every declared host where:

```nix
host.systemTargetKind == "nixos"
host.system == system
```

derive its target name directly with `targetNames.mkSystemTargetName` using
the host's default theme/default session and target-axis policy.

Pass:

```text
host registry key
target name
primaryAccountName
dotfilesSource
```

to the ISO constructor.

Do not require facter and do not evaluate `nixosConfigurations.<target>`.

- [ ] **Step 12: Make tty1 ownership fail closed**

The minimal ISO keeps tty2 as the wanted diagnostic console:

```nix
systemd.targets.getty.wants =
  lib.mkForce [ "autovt@tty2.service" ];
```

Mask exact tty1 instances:

```nix
systemd.services."getty@tty1".enable = false;
systemd.services."autovt@tty1".enable = false;
```

Configure the installer:

```nix
systemd.services.dotfiles-installer = {
  wantedBy = [ "multi-user.target" ];
  after = [ "network-online.target" ];
  wants = [ "network-online.target" ];

  serviceConfig = {
    Type = "exec";
    StandardInput = "tty-force";
    StandardOutput = "tty";
    StandardError = "tty";
    TTYPath = "/dev/tty1";
    TTYReset = true;
  };
};
```

Do not rely on `Conflicts=` for tty1 ownership.

- [ ] **Step 13: Implement the thin generic builder**

The build app receives the immutable filtered `dotfilesSource` store path
already captured when `nix run path:.#build-installer` was evaluated.

For `--host HOST`, run:

```text
nix build path:<dotfilesSource>#installer-HOST
  --out-link <current-directory>/result/installer-HOST
```

The source path is immutable, so mutation of the original working directory
after app startup cannot change the ISO being built.

There are no Git, revision, publication, or remote checks.

- [ ] **Step 14: Test builder/ISO wiring**

Builder tests prove:

- requested host maps only to `installer-HOST`;
- unknown/non-NixOS host fails;
- build reference points at the embedded immutable source store path, not the
  mutable current directory;
- no command invokes Git.

ISO structural tests prove:

- a facter-less host can construct its installer package;
- the embedded source is the filtered snapshot;
- installer service is `Type=exec`;
- exact tty1 getty/autovt units are masked;
- tty2 remains available;
- runtime script contains explicit required executable store paths.

- [ ] **Step 15: Run checks and commit**

```bash
nix flake check -L path:.
nix run path:.#build-installer -- --help
git add nix/installer nix/flake/installer.nix nix/apps/build-installer nix/flake/default.nix nix/flake/apps.nix nix/tests/installer/runtime.nix nix/checks.nix
git commit -m "feat: build installer from dotfiles snapshot"
```

---

### Task 4: Verify the Complete Snapshot-Based Lifecycle

**Files:**
- Create: `nix/tests/installer/e2e.nix`
- Create: `nix/apps/test-installer-e2e/default.nix`
- Modify: `nix/flake/apps.nix`
- Modify: `nix/checks.nix`
- Modify: `README.org`
- Modify: `flake.nix`

**Interfaces:**
- E2E app: `nix run path:.#test-installer-e2e`.
- It boots the actual installer ISO generated from the current filtered
  filesystem snapshot.

- [ ] **Step 1: Expose the lifecycle driver as an app**

Construct the NixOS test driver as a derivation, but run
`driverInteractive/bin/nixos-test-driver --no-interactive` from the app.

The test may use runtime network access for locked Nix dependencies. It has no
Git-server/repository dependency.

- [ ] **Step 2: Model only supported hardware**

The VM has:

- UEFI;
- actual generated installer ISO as CD media;
- exactly one writable non-removable internal disk;
- network;
- no second `dotfiles-system` disk.

- [ ] **Step 3: Verify tty ownership under VT switching**

Boot to the installer password prompt.

Assert:

```text
dotfiles-installer.service = active
getty@tty1.service         = masked/inactive
autovt@tty1.service        = masked/inactive
```

Switch tty1 -> tty2 -> tty1 and assert the installer remains active and the
password prompt remains the tty1 owner.

- [ ] **Step 4: Run the successful snapshot install**

Feed a deterministic test password and verify:

1. runtime source is copied from the embedded immutable snapshot;
2. ignored fixture/local-state paths are absent;
3. fresh host facter is generated;
4. `nixosConfigurations.<target>` exists after facter generation;
5. final evaluation and Disko-script build use `path:` plus
   `--no-update-lock-file`;
6. exactly-one-disk barrier succeeds;
7. Disko creates `dotfiles-system`, `@root`, `@nix`, `@persist`;
8. password hash is placed under `/persist`;
9. target-store `nixos-install` succeeds;
10. fallback EFI loader exists;
11. plain dotfiles tree is persisted with evaluated UID/GID;
12. installer powers off.

- [ ] **Step 5: Boot installed disk without installer media**

Restart without the installer CD and require:

```text
/        -> @root
/nix     -> @nix
/persist -> @persist
multi-user.target reached
```

- [ ] **Step 6: Verify authentication, impermanence, and update viability**

Using the deterministic password:

- local login works;
- `sudo` works.

Create disposable and preserved state, reboot, and prove root reset/persistence.

Then from the installed plain dotfiles directory, run the update app's
non-destructive test path or `--help`/fixture-backed invocation and prove it
does not require `.git`. Do not perform an uncontrolled real dependency
update inside the E2E.

- [ ] **Step 7: Keep `nix flake check` deterministic**

```bash
nix flake check -L path:.
```

This executes structural/unit checks and the small deterministic impermanence VM
only. It does not execute the full network-capable installer lifecycle.

- [ ] **Step 8: Update operator documentation**

Document the source model explicitly:

```text
dotfiles filesystem
→ .gitignore-filtered immutable snapshot
→ installer ISO
→ writable copy + facter
→ installed/persisted dotfiles
```

Document operator flow:

```text
1. edit dotfiles to desired state
2. nix run path:.#build-installer -- --host HOST
3. write/attach result/installer-HOST
4. boot installer
5. enter administrator password
6. wait for poweroff
7. remove/eject installer media
8. power on
```

Update `flake.nix` usage comments to use explicit `path:.` for dotfiles
operations whose intended source is the current filesystem snapshot.

State explicitly that commits, branches, remotes, publication, and Git history
are outside installer correctness.

- [ ] **Step 9: Run lifecycle E2E**

```bash
nix run path:.#test-installer-e2e
```

Expected: PASS.

If required KVM/virtualization support is unavailable, report that environmental
limitation; do not introduce a slower fallback solely for the test.

- [ ] **Step 10: Build the real ISO but do not boot it**

```bash
nix run path:.#build-installer -- --host aarch64-linux-a
test -e result/installer-aarch64-linux-a
```

The artifact represents the current filtered filesystem snapshot; there is no
commit/revision assertion.

**STOP HERE. Do not boot the ISO on the real machine as part of implementation.**

- [ ] **Step 11: Commit**

```bash
git add nix/tests/installer/e2e.nix nix/apps/test-installer-e2e nix/flake/apps.nix nix/checks.nix README.org flake.nix
git commit -m "test: cover snapshot installer lifecycle"
```

---

## Plan Self-Review Checklist

- [ ] Generic `build-installer --host HOST` remains.
- [ ] Installer source identity contains no Git history/revision/remote concept.
- [ ] `path:.` is intentional operator semantics, not a compatibility workaround.
- [ ] Source filtering excludes ignored local state and `.git`.
- [ ] Newly created implementation files are visible to tests before commit.
- [ ] Facter-less NixOS hosts keep installer packages without exporting final configurations.
- [ ] No `hardware-configuration.nix` fallback.
- [ ] No facter Git commit.
- [ ] No `--no-write-lock-file` in installer commands.
- [ ] No remote-main/source acceptance barrier; only the final disk barrier remains.
- [ ] No filesystem UUID/public storage option/configurable topology.
- [ ] No bootstrap-credentials wrapper.
- [ ] No public ephemeral-root interface.
- [ ] Installer runtime closure explicitly contains Nushell and nixos-facter.
- [ ] tty1 instances are masked and installer uses `Type=exec`.
- [ ] Exactly one deterministic impermanence VM remains.
- [ ] Full E2E uses the actual snapshot-built ISO.
- [ ] Persisted dotfiles contain no required Git metadata.
- [ ] Update locking works without a Git repository.
- [ ] Real-machine boot remains outside implementation scope.
