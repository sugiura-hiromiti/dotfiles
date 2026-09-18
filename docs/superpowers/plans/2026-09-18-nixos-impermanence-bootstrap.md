# NixOS Impermanence Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement generic `build-installer --host HOST` from the current non-ignored dotfiles filesystem snapshot, generate fresh facter data at install time, provision one fixed Disko/impermanence layout, install the final NixOS configuration, persist the resulting plain dotfiles tree, and power off for manual media removal.

**Architecture:** Git history is not part of installer correctness. A small snapshot helper filters the operator's current directory with pinned `nix-gitignore` *before* adding it to the Nix store; the builder then constructs the ISO only from that immutable store path. Runtime copies the embedded snapshot writable, adds facter, evaluates it with explicit `path:` semantics, performs one disk acceptance barrier, installs, and persists that same tree.

**Tech Stack:** NixOS/nixpkgs, flake-parts, Disko, nixos-facter, preservation, Nushell, nix-gitignore, systemd-boot, NixOS VM tests.

**Spec:** `docs/superpowers/specs/2026-09-18-nixos-impermanence-bootstrap-design.md`

## Global Constraints

- Canonical operator command: `nix run .#build-installer -- --host HOST`.
- Builder performs no commit/branch/remote/index/cleanliness/history checks.
- Current non-ignored files, including non-ignored untracked files, are installer source.
- Ignored local state and `.git` are filtered before the dotfiles source enters the Nix store.
- Do not bootstrap the builder itself with top-level `path:.`.
- Final NixOS configurations require facter; there is no legacy hardware fallback.
- Facter-less declared NixOS hosts still have installer packages.
- Installer-side flake operations use `--no-update-lock-file`, not `--no-write-lock-file`.
- Fixed storage: GPT + ESP + `dotfiles-system` Btrfs + `@root`, `@nix`, `@persist`.
- Disko target alias: `/dev/dotfiles-install-target`.
- No public storage device/UUID/label/subvolume/provisioning option surface.
- Root reset is internal to impermanence.
- Password policy is direct NixOS user configuration.
- Exactly one disk scan is correctness-critical: the final destructive barrier.
- Installer runtime dependencies are explicit Nix store paths.
- tty1 getty/autovt instances are masked; installer uses `Type=exec`; tty2 is diagnostic.
- EFI-variable writes remain disabled.
- Installed dotfiles are a plain filesystem snapshot and contain no required Git metadata.
- Existing `.#update` behavior is not redesigned by this plan.
- Keep one deterministic impermanence boot/reboot VM plus one full installer lifecycle E2E.
- Implementation does not boot the installer on the user's real machine.

### Development-only source visibility

The installer has no Git source invariant. However, while implementing this
plan, Nix may load the *development flake* through ordinary Git-flake semantics.

Before a Nix evaluation imports a newly created source path, make that path
visible to the development flake, for example in a colocated Git worktree:

```bash
git add -N <new-path>
```

This is only a development/test sequencing requirement. It is not part of
`build-installer` behavior and does not constrain the dotfiles snapshot.

---

## File Structure

```text
nix/
├── lib/
│   └── source-snapshot.nix
├── installer/
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
│   ├── fixtures/source-snapshot/
│   │   ├── .gitignore
│   │   ├── kept.txt
│   │   └── ignored-state/secret.txt
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

Delete:

```text
nix/modules/nixos/features/storage/default.nix
nix/modules/nixos/features/impermanence/ephemeral-root.nix
nix/tests/nixos/ephemeral-root.nix
nix/tests/nixos/storage-provisioning-vm.nix
```

Keep exactly one behavioral impermanence VM:
`nix/tests/nixos/impermanence-vm.nix`.

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
- The user migrates the current `aarch64-linux-a` host to valid
  `facter.json` before this task removes its legacy hardware import.
- If that is not yet true, stop rather than adding compatibility logic.

**Interfaces:**
- Internal layout constants:
  `dotfiles-system`, `@root`, `@nix`, `@persist`,
  `/dev/dotfiles-install-target`.
- `nixosHostReady hostName -> bool`: whether that host has `facter.json`.
- Final exported NixOS configurations always use facter, fixed Disko topology,
  preservation/impermanence, and direct password-file policy.

- [ ] **Step 1: Rewrite storage/impermanence structural tests**

`storage-provisioning.nix` asserts:

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

`impermanence.nix` asserts the initrd units use
`PARTLABEL=dotfiles-system`, require exactly one device before deletion,
recreate `@root`, and mark `/nix` and `/persist` needed for boot.

- [ ] **Step 2: Run focused tests and observe failure**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).storage-provisioning
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).impermanence
```

- [ ] **Step 3: Add the fixed layout constants**

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

- [ ] **Step 4: Reduce Disko provisioning**

Rewrite `storage/provisioning.nix` to unconditionally declare the fixed
GPT/ESP/Btrfs layout.

Remove `filesystemUuid`, `dotfiles.features.storage.*`,
`provisioning.enable`, configurable disk/label/subvolume values, and Btrfs
UUID arguments.

Delete `storage/default.nix`.

- [ ] **Step 5: Fold root reset into impermanence**

Move the initrd root-reset behavior into `impermanence.nix`.

Before touching `@root`, execute the Nix-store `blkid` path with:

```text
-t PARTLABEL=dotfiles-system -o device
```

Normalize unique non-empty results and require exactly one.

Delete the public `ephemeralRoot` option family and
`ephemeral-root.nix`.

- [ ] **Step 6: Make constructed NixOS configs facter-only**

Every NixOS configuration that is constructed includes:

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

No legacy conditional belongs in the constructor.

- [ ] **Step 7: Omit facter-less final configs, not installer hosts**

Define once in `flake/default.nix`:

```nix
nixosHostReady =
  hostName:
  builtins.pathExists (../profiles/hosts + "/${hostName}/facter.json");
```

Pass it to `flake/configurations.nix` and `flake/checks.nix`.

Filter final NixOS target entries by `entry.config.host`. Home/Darwin outputs
remain unchanged.

Task 3 installer package generation must deliberately ignore this predicate.

- [ ] **Step 8: Keep one deterministic root-reset VM**

Simplify `impermanence-vm.nix` to:

```text
fixed Disko layout
→ boot
→ create disposable + preserved markers
→ reboot
→ disposable marker absent
→ preserved marker present
→ @root exists
```

Delete the standalone storage-provisioning VM and ephemeral-root test.

- [ ] **Step 9: Run deterministic checks**

```bash
nix flake check -L
```

Expected: PASS after current-host facter migration.

- [ ] **Step 10: Commit**

```bash
git add -A nix/modules/nixos nix/configurations/nixos.nix nix/flake nix/tests/nixos nix/checks.nix
git commit -m "refactor: collapse nixos bootstrap state"
```

---

### Task 2: Create a Safe Filesystem Snapshotter and Generic ISO Builder

**Files:**
- Create: `nix/lib/source-snapshot.nix`
- Create: `nix/apps/build-installer/default.nix`
- Create: `nix/apps/build-installer/build.nu`
- Create: `nix/apps/build-installer/tests/run.sh`
- Create: `nix/installer/iso.nix`
- Create: `nix/flake/installer.nix`
- Create: `nix/tests/fixtures/source-snapshot/.gitignore`
- Create: `nix/tests/fixtures/source-snapshot/kept.txt`
- Create: `nix/tests/fixtures/source-snapshot/ignored-state/secret.txt`
- Modify: `nix/flake/default.nix`
- Modify: `nix/flake/apps.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- `mkSourceSnapshotter { pkgs } -> executable`.
- Snapshotter CLI: `dotfiles-source-snapshot ROOT`, prints one immutable Nix
  store path.
- Packages: `packages.installer-<host>` for every declared NixOS host on the
  matching system.
- App: `nix run .#build-installer -- --host HOST`.
- Builder output: `result/installer-HOST`.

- [ ] **Step 1: Add source-filter and builder command tests**

Before evaluating new files, make them visible to the development flake:

```bash
git add -N   nix/lib/source-snapshot.nix   nix/apps/build-installer/default.nix   nix/apps/build-installer/build.nu   nix/apps/build-installer/tests/run.sh   nix/installer/iso.nix   nix/flake/installer.nix   nix/tests/fixtures/source-snapshot/.gitignore   nix/tests/fixtures/source-snapshot/kept.txt   nix/tests/fixtures/source-snapshot/ignored-state/secret.txt
```

The source fixture contains:

```text
.gitignore:
  /ignored-state/

kept.txt:
  kept

ignored-state/secret.txt:
  must-not-enter-source
```

A Nix structural test applies
`pkgs.nix-gitignore.gitignoreSource [ ]` to the fixture and asserts
`kept.txt` exists while `ignored-state/secret.txt` does not.

Builder shell tests fake `nix build` and prove:

- `--host aarch64-linux-a` requests only
  `path:<snapshot>#installer-aarch64-linux-a`;
- unknown/non-NixOS hosts fail;
- no command invokes Git;
- no commit/revision/remote check exists.

- [ ] **Step 2: Run the focused checks and observe failure**

```bash
nix flake check -L
```

Expected: new snapshot/builder interfaces are missing.

- [ ] **Step 3: Implement the snapshotter**

`source-snapshot.nix` creates a small executable plus an embedded Nix
expression.

The embedded expression is:

```nix
let
  pkgs = import ${pkgs.path} { };
  root = builtins.toPath (builtins.getEnv "DOTFILES_SOURCE_ROOT");
in
toString (pkgs.nix-gitignore.gitignoreSource [ ] root)
```

The executable:

1. requires exactly one root argument;
2. canonicalizes it;
3. sets `DOTFILES_SOURCE_ROOT`;
4. runs pinned Nix with
   `nix eval --impure --raw --file <expression>`;
5. prints the resulting store path.

The filesystem root is the only intended impurity.

Do not run `nix eval path:ROOT`; filtering must occur before root ingestion.

- [ ] **Step 4: Generate installer packages from all declared NixOS hosts**

Create `flake/installer.nix`.

For every host with:

```nix
host.systemTargetKind == "nixos"
host.system == system
```

derive the target name directly from:

```text
host.targetHost
host.runtime.defaultTheme
host.runtime.defaultSession
host.runtime.targetAxes
```

and `targetNames.mkSystemTargetName`.

Pass `host`, target name, primary account, and `self.outPath` to the ISO
constructor.

Do not evaluate final `nixosConfigurations` and do not require facter.

When this flake is evaluated as `path:<filtered-snapshot>`, `self.outPath`
is exactly the immutable filtered source that the ISO must embed.

- [ ] **Step 5: Create the ISO shell without the final installer transaction**

`iso.nix` imports the pinned minimal installation-CD module and accepts:

```nix
{
  host,
  target,
  primaryAccount,
  source,
}
```

It derives EFI architecture from the ISO platform.

At this task boundary, wire this explicit temporary executable from the Nix
store; Task 3 replaces it with the real installer script:

```nix
pkgs.writeShellScript "dotfiles-installer-unimplemented" ''
  echo "installer transaction not implemented" >&2
  echo "host=${host} target=${target} source=${source}" >&2
  exit 1
''
```

This permits testing package generation/source embedding/console wiring without
coupling Task 2 to transaction implementation.

- [ ] **Step 6: Configure fail-closed tty1 ownership**

Keep tty2:

```nix
systemd.targets.getty.wants =
  lib.mkForce [ "autovt@tty2.service" ];
```

Mask exact tty1 instances:

```nix
systemd.services."getty@tty1".enable = false;
systemd.services."autovt@tty1".enable = false;
```

Configure the installer service with:

```nix
wantedBy = [ "multi-user.target" ];

serviceConfig = {
  Type = "exec";
  StandardInput = "tty-force";
  StandardOutput = "tty";
  StandardError = "tty";
  TTYPath = "/dev/tty1";
  TTYReset = true;
};
```

Task 3 adds network ordering only if the real installer actually requires it at
service start; do not add it merely because the old Git design did.

- [ ] **Step 7: Implement the thin builder**

`build.nu`:

1. resolves `pwd` as the dotfiles source root;
2. validates `--host` against the embedded declared-NixOS-host list;
3. runs `dotfiles-source-snapshot <pwd>`;
4. stores the printed immutable path as `snapshot`;
5. runs:

```text
nix build path:<snapshot>#installer-HOST
  --out-link <pwd>/result/installer-HOST
```

The build command never rereads the mutable source tree.

- [ ] **Step 8: Test mutation safety**

In `tests/run.sh`, fake the snapshotter to return an immutable fixture path,
then mutate the original source directory before fake `nix build` is allowed
to proceed.

Assert the build argument still references only the returned snapshot path.

This is the replacement for all old Git-revision TOCTOU tests.

- [ ] **Step 9: Run checks and commit**

```bash
nix flake check -L
nix run .#build-installer -- --help
git add nix/lib/source-snapshot.nix nix/apps/build-installer nix/installer/iso.nix nix/flake/installer.nix nix/flake/default.nix nix/flake/apps.nix nix/tests/fixtures/source-snapshot nix/checks.nix
git commit -m "feat: build installer from filesystem snapshot"
```

---

### Task 3: Implement the Installer Transaction Inside the Snapshot ISO

**Files:**
- Create: `nix/installer/install.nu`
- Create: `nix/installer/script.nix`
- Modify: `nix/installer/iso.nix`
- Create: `nix/tests/installer/runtime.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- `mkInstallerScript { host; target; primaryAccount; source; efiArch; }`.
- Immutable source: Nix store path embedded in ISO.
- Writable source: `/run/dotfiles-installer/source`.
- Destructive alias: `/dev/dotfiles-install-target`.

- [ ] **Step 1: Write transaction tests**

Make `install.nu` visible to the development flake before first import:

```bash
git add -N nix/installer/install.nu nix/installer/script.nix nix/tests/installer/runtime.nix
```

With fake executables, prove:

1. immutable source is copied to writable source;
2. facter is written under the selected host;
3. final flake references are
   `path:/run/dotfiles-installer/source#...`;
4. every installer `nix eval`, `nix build`, and `nixos-install` flake
   operation has `--no-update-lock-file`;
5. no installer command invokes Git or `nix flake update`;
6. zero/multiple eligible disks abort before alias/Disko;
7. exactly one eligible disk permits alias creation/Disko.

- [ ] **Step 2: Package every runtime executable explicitly**

`script.nix` embeds store paths for:

```text
nu              = pkgs.nushell
nixos-facter    = pkgs.nixos-facter
nix             = pkgs.nix
nixos-install   = pkgs.nixos-install-tools/bin/nixos-install
mkpasswd        = pkgs.mkpasswd
lsblk/findmnt   = pkgs.util-linux
cp/chmod/chown/ln/mkdir/rm/sync = pkgs.coreutils
systemctl       = pkgs.systemd
```

Add a structural assertion that generated script text contains the Nushell and
nixos-facter store paths.

Git is absent from the runtime closure.

- [ ] **Step 3: Copy the immutable source writable**

At runtime:

```text
remove old /run/dotfiles-installer/source
copy embedded source there recursively
make the copied tree owner-writable
```

Do not modify the embedded store source.

- [ ] **Step 4: Prompt and hash password**

Prompt twice with echo disabled, reject empty/mismatch, hash through
`mkpasswd --method=yescrypt --stdin`, and retain only the hash.

- [ ] **Step 5: Generate facter directly**

Run:

```text
nixos-facter -o   /run/dotfiles-installer/source/nix/profiles/hosts/<host>/facter.json
```

No Git operation follows.

- [ ] **Step 6: Evaluate final config with explicit path semantics**

Using `--no-update-lock-file`, evaluate:

```text
path:/run/dotfiles-installer/source#nixosConfigurations.<target>.config.system.build.toplevel.drvPath
path:/run/dotfiles-installer/source#nixosConfigurations.<target>.config.users.users.<primary>.home
path:/run/dotfiles-installer/source#nixosConfigurations.<target>.config.users.users.<primary>.uid
path:/run/dotfiles-installer/source#nixosConfigurations.<target>.config.users.users.<primary>.group
path:/run/dotfiles-installer/source#nixosConfigurations.<target>.config.users.groups.<group>.gid
path:/run/dotfiles-installer/source#nixosConfigurations.<target>.config.users.users.<primary>.hashedPasswordFile
```

Reject null/non-integer UID/GID and empty group/hash path.

- [ ] **Step 7: Realize only Disko before destruction**

Build:

```text
path:/run/dotfiles-installer/source#nixosConfigurations.<target>.config.system.build.diskoScript
```

with:

```text
--no-update-lock-file --no-link --print-out-paths
```

- [ ] **Step 8: Perform the single destructive barrier**

Run:

```text
lsblk --json --output PATH,TYPE,RM,HOTPLUG
```

Require exactly one whole disk where `RM=0`, `HOTPLUG=0`.

Only then create:

```text
/dev/dotfiles-install-target -> selected disk
```

No earlier disk scan or source/network/Git acceptance barrier exists.

- [ ] **Step 9: Provision, write secret, install**

Run Disko. Require `/mnt`, `/mnt/boot`, `/mnt/nix`, `/mnt/persist`
mountpoints.

Write the password hash to `/mnt + hashedPasswordFile`, parent `0700`,
file `0600`.

Run:

```bash
nixos-install \
  --root /mnt \
  --flake "path:/run/dotfiles-installer/source#$target" \
  --no-update-lock-file \
  --no-channel-copy \
  --no-root-password
```

- [ ] **Step 10: Verify fallback EFI and persist dotfiles**

Require:

```text
/mnt/boot/EFI/BOOT/BOOT<UPPERCASE_EFI_ARCH>.EFI
```

Copy the complete writable snapshot to:

```text
/mnt/persist + <evaluated home> + /dotfiles
```

and recursively chown it to evaluated UID:GID.

Do not create/copy Git metadata.

- [ ] **Step 11: Complete safely**

Run `sync`, recursively unmount `/mnt`, verify it is no longer mounted, then
`systemctl poweroff`.

Earlier failures remain on the installer for diagnosis.

- [ ] **Step 12: Replace the temporary failing stub with the real installer**

Wire `mkInstallerScript` into `iso.nix`.

If the installer needs network for Nix fetches, depend on
`network-online.target`; the source snapshot itself requires no network.

- [ ] **Step 13: Run checks and commit**

```bash
nix flake check -L
git add nix/installer nix/tests/installer/runtime.nix nix/checks.nix
git commit -m "feat: install nixos from embedded snapshot"
```

---

### Task 4: Verify the Complete Snapshot Lifecycle

**Files:**
- Create: `nix/tests/installer/e2e.nix`
- Create: `nix/apps/test-installer-e2e/default.nix`
- Modify: `nix/flake/apps.nix`
- Modify: `nix/checks.nix`
- Modify: `README.org`
- Modify: `flake.nix`

**Interfaces:**
- E2E app: `nix run .#test-installer-e2e`.
- E2E uses the same source-snapshotter as `build-installer`.

- [ ] **Step 1: Make new E2E paths development-visible**

```bash
git add -N nix/tests/installer/e2e.nix nix/apps/test-installer-e2e/default.nix
```

- [ ] **Step 2: Construct the E2E from an immutable filtered snapshot**

The outer E2E app:

1. snapshots the current working directory through
   `dotfiles-source-snapshot`;
2. builds the inner E2E driver from
   `path:<snapshot>#installer-e2e-driver`;
3. runs `driverInteractive/bin/nixos-test-driver --no-interactive`.

Thus the ISO and driver are derived from the same immutable filesystem snapshot.

The E2E may use runtime network access for locked Nix dependencies. It does not
contact or validate a Git repository.

- [ ] **Step 3: Model supported hardware**

The VM has UEFI, the real installer ISO as CD media, exactly one writable
non-removable internal disk, network, and no second `dotfiles-system` disk.

- [ ] **Step 4: Verify tty ownership survives VT switching**

At the password prompt assert:

```text
dotfiles-installer.service = active
getty@tty1.service         = masked/inactive
autovt@tty1.service        = masked/inactive
```

Switch tty1 -> tty2 -> tty1 and verify the installer remains active and owns the
prompt.

- [ ] **Step 5: Verify the snapshot/facter/install transaction**

Feed a deterministic test password and verify:

1. writable runtime source derives from the embedded snapshot;
2. an ignored fixture marker is absent;
3. fresh facter is generated;
4. final `nixosConfigurations.<target>` exists after facter creation;
5. evaluation uses `path:` and `--no-update-lock-file`;
6. single-disk barrier succeeds;
7. fixed Disko topology is created;
8. password hash is under `/persist`;
9. target-store `nixos-install` succeeds;
10. fallback EFI loader exists;
11. plain dotfiles snapshot persists with evaluated UID/GID;
12. installer powers off.

- [ ] **Step 6: Boot installed disk without ISO**

Restart without installer media and require:

```text
/        -> @root
/nix     -> @nix
/persist -> @persist
multi-user.target reached
```

- [ ] **Step 7: Verify authentication and root reset**

Prove local password login and sudo.

Create disposable root state and preserved state, reboot, then assert root state
vanished, preserved state survived, and `@root` was recreated.

- [ ] **Step 8: Keep ordinary checks deterministic**

```bash
nix flake check -L
```

This executes structural/unit checks plus the small deterministic impermanence
VM, but not the full network-capable installer lifecycle.

- [ ] **Step 9: Update operator documentation**

Document:

```text
current dotfiles directory
→ .gitignore-filtered store snapshot
→ installer ISO
→ writable copy + fresh facter
→ installed/persisted plain dotfiles
```

Operator flow:

```text
1. edit dotfiles to desired state
2. nix run .#build-installer -- --host HOST
3. write/attach result/installer-HOST
4. boot installer
5. enter password
6. wait for poweroff
7. remove/eject media
8. power on
```

State explicitly:

- Git history/commit/branch/remote state is irrelevant to installer correctness;
- non-ignored current files are captured;
- ignored local state is not embedded;
- persisted dotfiles do not require Git metadata;
- redesigning `.#update` for a VCS-free persisted directory is separate work.

Remove installer documentation that says `path:.` is the top-level builder
invocation.

- [ ] **Step 10: Run the full lifecycle**

```bash
nix run .#test-installer-e2e
```

Expected: PASS.

If KVM/required virtualization is unavailable, report the environmental
limitation rather than adding a slower fallback solely for the test.

- [ ] **Step 11: Build the real ISO but do not boot it**

```bash
nix run .#build-installer -- --host aarch64-linux-a
test -e result/installer-aarch64-linux-a
```

There is no commit/publication/revision assertion.

**STOP HERE. Do not boot the ISO on the real machine as part of implementation.**

- [ ] **Step 12: Commit**

```bash
git add nix/tests/installer/e2e.nix nix/apps/test-installer-e2e nix/flake/apps.nix nix/checks.nix README.org flake.nix
git commit -m "test: cover snapshot installer lifecycle"
```

---

## Plan Self-Review Checklist

- [ ] Generic `build-installer --host HOST` remains.
- [ ] Installer correctness contains no Git history/revision/branch/remote/index invariant.
- [ ] Top-level `path:.` is not used to bootstrap the builder.
- [ ] Source filter runs before dotfiles ingestion into the Nix store.
- [ ] Non-ignored untracked files are included.
- [ ] Ignored local state and `.git` are excluded.
- [ ] Facter-less NixOS hosts keep installer packages without final configurations.
- [ ] No `hardware-configuration.nix` fallback.
- [ ] No facter Git commit.
- [ ] No `--no-write-lock-file` in installer commands.
- [ ] No source/remote acceptance barrier; only final disk acceptance remains.
- [ ] No filesystem UUID/public storage option/configurable topology.
- [ ] No bootstrap-credentials wrapper.
- [ ] No public ephemeral-root interface.
- [ ] Installer runtime explicitly closes over Nushell and nixos-facter.
- [ ] tty1 exact instances are masked and installer uses `Type=exec`.
- [ ] Exactly one deterministic impermanence VM remains.
- [ ] Full E2E uses the same filtered immutable snapshot as the builder.
- [ ] Persisted dotfiles contain no required Git metadata.
- [ ] Existing update workflow remains outside this installer redesign.
- [ ] Real-machine boot remains outside implementation scope.
