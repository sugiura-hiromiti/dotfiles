# NixOS Impermanence Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build generic NixOS installation media from the current filtered dotfiles filesystem, generate facter on the target machine, install one fixed impermanent layout, and verify the complete lifecycle.

**Architecture:** `build-installer` receives a filtered immutable source path during impure flake evaluation, so runtime building never consults Git history or rereads mutable source files. The ISO copies that source writable, adds facter, evaluates the final configuration, validates one target disk, installs, and persists the same dotfiles tree.

**Tech Stack:** NixOS/nixpkgs, flake-parts, Disko, nixos-facter, preservation, Nushell, nix-gitignore, systemd-boot, NixOS VM tests.

**Spec:** `docs/superpowers/specs/2026-09-18-nixos-impermanence-bootstrap-design.md`

## Global Constraints

- Operator command: `nix run --impure .#build-installer -- --host HOST`.
- The build app filters `$PWD` with `pkgs.nix-gitignore.gitignoreSource [ ]` during impure evaluation.
- ISO building uses only the resulting immutable store path.
- Final NixOS configurations exist only for hosts with `facter.json`.
- Installer Nix operations use `--no-update-lock-file`.
- Storage constants are fixed: `dotfiles-system`, `@root`, `@nix`, `@persist`, `/dev/dotfiles-install-target`.
- Exactly one non-removable, non-hotplug whole disk is required before Disko.
- Password policy is owned by the final NixOS configuration.
- tty1 belongs to the installer; tty2 remains diagnostic.
- EFI-variable writes remain disabled.
- Keep one deterministic impermanence VM and one full installer E2E.
- Real-machine boot is outside implementation scope.

**Executor note:** ordinary Git-flake development may not see newly created files until they are made visible to the worktree index (for example `git add -N path`). This is only an implementation workflow detail.

---

## File Structure

- `nix/modules/nixos/features/storage/layout.nix` — fixed storage constants.
- `nix/modules/nixos/features/storage/provisioning.nix` — fixed Disko layout.
- `nix/modules/nixos/features/impermanence/ephemeral-root.nix` — internal fixed root-reset module; no public options.
- `nix/configurations/nixos.nix` — facter-backed final NixOS policy.
- `nix/flake/configurations.nix` / `nix/flake/checks.nix` — omit facter-less final targets.
- `nix/installer/install.nu` / `script.nix` — installer transaction and packaged runtime.
- `nix/installer/iso.nix` — installer ISO and console ownership.
- `nix/flake/installer.nix` — `installer-HOST` packages for all NixOS hosts.
- `nix/apps/build-installer/` — thin generic build app.
- `nix/tests/installer/e2e.nix` — complete ISO-to-installed-system lifecycle.

---

### Task 1: Make the Final NixOS Model Facter-Only and Fixed

**Files:**
- Create: `nix/modules/nixos/features/storage/layout.nix`
- Modify: `nix/modules/nixos/features/storage/provisioning.nix`
- Delete: `nix/modules/nixos/features/storage/default.nix`
- Modify: `nix/modules/nixos/features/impermanence/ephemeral-root.nix`
- Modify: `nix/modules/nixos/features/impermanence/impermanence.nix`
- Modify: `nix/configurations/nixos.nix`
- Modify: `nix/modules/nixos/default.nix`
- Modify: `nix/flake/configurations.nix`
- Modify: `nix/flake/checks.nix`
- Modify: `nix/flake/default.nix`
- Modify: `nix/tests/nixos/storage-provisioning.nix`
- Modify: `nix/tests/nixos/impermanence.nix`
- Modify: `nix/tests/nixos/impermanence-vm.nix`
- Delete: `nix/tests/nixos/ephemeral-root.nix`
- Delete: `nix/tests/nixos/storage-provisioning-vm.nix`
- Modify: `nix/checks.nix`

**Precondition:** the current production NixOS host has been migrated by the user to a valid `facter.json`. If not, stop; do not add a compatibility path.

**Interfaces:**
- `layout.nix` exports `partitionLabel`, `rootSubvolume`, `nixSubvolume`, `persistSubvolume`, `installDisk`.
- `nixosHostReady hostName -> bool`.
- `ephemeral-root.nix` is internal to impermanence and takes fixed layout constants instead of NixOS options.

- [ ] **Step 1: Rewrite the storage and impermanence tests around the fixed contract**

`storage-provisioning.nix` must assert:

```nix
assert disk.device == "/dev/dotfiles-install-target";
assert disk.content.partitions.ESP.content.mountpoint == "/boot";
assert disk.content.partitions.system.label == "dotfiles-system";
assert disk.content.partitions.system.content.subvolumes ? "@root";
assert disk.content.partitions.system.content.subvolumes ? "@nix";
assert disk.content.partitions.system.content.subvolumes ? "@persist";
```

`impermanence.nix` must assert that `/nix` and `/persist` are needed for boot and that the root-reset unit invokes the fixed `dotfiles-system` / `@root` logic.

Run:

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).storage-provisioning
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).impermanence
```

Expected: FAIL against the current configurable model.

- [ ] **Step 2: Replace the storage option model with constants**

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

Rewrite `provisioning.nix` to declare the GPT/ESP/Btrfs layout directly from these constants. Remove filesystem UUID handling and the public `dotfiles.features.storage` option model, then delete `storage/default.nix` and its import from `modules/nixos/default.nix`.

- [ ] **Step 3: Make root reset an internal fixed module**

Keep `ephemeral-root.nix` as a focused internal module, but delete its public `dotfiles.features.ephemeralRoot` options.

Its initrd service must run the store path for:

```text
blkid -t PARTLABEL=dotfiles-system -o device
```

Require exactly one unique non-empty result before mounting the Btrfs top level or deleting `@root`. Delete/recreate the fixed `@root` subvolume, then allow `sysroot.mount`.

`impermanence.nix` imports/configures this internal module and marks `/nix` and `/persist` needed for boot.

- [ ] **Step 4: Make final NixOS construction facter-only**

In `configurations/nixos.nix`, every constructed NixOS target includes:

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

Do not inspect or import `hardware-configuration.nix`.

- [ ] **Step 5: Omit facter-less final configurations**

Define once:

```nix
nixosHostReady =
  hostName:
  builtins.pathExists (../profiles/hosts + "/${hostName}/facter.json");
```

Pass it into `flake/configurations.nix` and `flake/checks.nix`. Filter NixOS target entries before constructing final configurations/build checks. Home and Darwin targets remain unchanged.

- [ ] **Step 6: Keep one behavioral impermanence VM**

Simplify `impermanence-vm.nix` to prove only:

```text
provision fixed layout
→ boot
→ create disposable root marker + persistent marker
→ reboot
→ disposable marker absent
→ persistent marker present
→ @root exists
```

Delete `storage-provisioning-vm.nix` and the standalone `ephemeral-root.nix` test.

- [ ] **Step 7: Verify and commit**

```bash
nix flake check -L
git add -A nix/modules/nixos nix/configurations/nixos.nix nix/flake nix/tests/nixos nix/checks.nix
git commit -m "refactor: fix nixos bootstrap model"
```

---

### Task 2: Implement the Installer Transaction

**Files:**
- Create: `nix/installer/install.nu`
- Create: `nix/installer/script.nix`
- Create: `nix/tests/installer/runtime.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- `mkInstallerScript { host; target; primaryAccount; source; efiArch; }`.
- Embedded source is an immutable Nix store path.
- Writable source is `/run/dotfiles-installer/source`.
- Disk alias is `/dev/dotfiles-install-target`.

- [ ] **Step 1: Write the transaction tests**

Make the new files visible to development evaluation, then test `install.nu` with fake external commands.

Required cases:

```text
embedded source copied writable
facter written for selected host
one final config evaluation uses path:/run/dotfiles-installer/source
all installer Nix operations include --no-update-lock-file
zero eligible disks -> abort before Disko
multiple eligible disks -> abort before Disko
one eligible disk -> create alias and continue
Git and nix flake update are never invoked
```

Run the focused installer-runtime check and confirm failure before implementation.

- [ ] **Step 2: Package the runtime through the systemd service PATH**

`script.nix` packages `install.nu` with immutable values for `host`, `target`, `primaryAccount`, `source`, and `efiArch`.

The ISO service in Task 3 will provide:

```nix
path = [
  pkgs.nushell
  pkgs.nixos-facter
  pkgs.nix
  pkgs.nixos-install-tools
  pkgs.mkpasswd
  pkgs.util-linux
  pkgs.coreutils
  pkgs.systemd
];
```

The transaction script therefore uses normal executable names; it does not maintain a second table of individual store paths.

- [ ] **Step 3: Implement reversible preparation**

The script:

1. copies `source` to `/run/dotfiles-installer/source`;
2. makes the copied tree owner-writable;
3. prompts twice for a non-empty matching password;
4. hashes it with `mkpasswd --method=yescrypt --stdin`;
5. runs:

```text
nixos-facter -o /run/dotfiles-installer/source/nix/profiles/hosts/<host>/facter.json
```

No destructive disk operation occurs in this step.

- [ ] **Step 4: Evaluate final configuration metadata in one Nix call**

Evaluate:

```text
path:/run/dotfiles-installer/source#nixosConfigurations.<target>.config
```

with `--no-update-lock-file --json --apply`.

The apply expression returns one object:

```nix
{
  toplevelDrv = config.system.build.toplevel.drvPath;
  home = user.home;
  uid = user.uid;
  group = user.group;
  gid = config.users.groups.${user.group}.gid;
  hashedPasswordFile = user.hashedPasswordFile;
}
```

where `user = config.users.users.<primaryAccount>`.

Reject missing/non-integer UID/GID and empty home/group/hash paths.

Then build only:

```text
path:/run/dotfiles-installer/source#nixosConfigurations.<target>.config.system.build.diskoScript
```

with:

```text
--no-update-lock-file --no-link --print-out-paths
```

- [ ] **Step 5: Implement the destructive barrier and installation**

Immediately before Disko:

```text
lsblk --json --output PATH,TYPE,RM,HOTPLUG
```

Require exactly one entry with `TYPE=disk`, `RM=0`, `HOTPLUG=0`, then create:

```text
/dev/dotfiles-install-target -> selected disk
```

Run Disko and require `/mnt`, `/mnt/boot`, `/mnt/nix`, and `/mnt/persist` to be mounted.

Write the password hash to `/mnt + hashedPasswordFile` with parent mode `0700` and file mode `0600`.

Install:

```bash
nixos-install \
  --root /mnt \
  --flake "path:/run/dotfiles-installer/source#$target" \
  --no-update-lock-file \
  --no-channel-copy \
  --no-root-password
```

- [ ] **Step 6: Verify boot state, persist source, and power off**

Require:

```text
/mnt/boot/EFI/BOOT/BOOT<ARCH>.EFI
```

Copy the writable source to:

```text
/mnt/persist + <home> + /dotfiles
```

and recursively chown to evaluated UID:GID.

Finally run `sync`, recursively unmount `/mnt`, verify it is unmounted, and call `systemctl poweroff`. Earlier errors exit non-zero without powering off.

- [ ] **Step 7: Verify and commit**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).installer-runtime
nix flake check -L
git add nix/installer/install.nu nix/installer/script.nix nix/tests/installer/runtime.nix nix/checks.nix
git commit -m "feat: add nixos installer transaction"
```

---

### Task 3: Add the Generic Builder, ISO, and Lifecycle E2E

**Files:**
- Create: `nix/installer/iso.nix`
- Create: `nix/flake/installer.nix`
- Create: `nix/apps/build-installer/default.nix`
- Create: `nix/apps/build-installer/build.nu`
- Create: `nix/apps/build-installer/tests/run.sh`
- Create: `nix/tests/installer/e2e.nix`
- Create: `nix/apps/test-installer-e2e/default.nix`
- Modify: `nix/flake/apps.nix`
- Modify: `nix/flake/default.nix`
- Modify: `nix/checks.nix`
- Modify: `README.org`
- Modify: `flake.nix`

**Interfaces:**
- `packages.installer-<host>` exists for every declared NixOS host on its system.
- `nix run --impure .#build-installer -- --host HOST`.
- `nix run --impure .#test-installer-e2e`.
- `packages.installer-e2e-driver` exposes the NixOS test driver's
  `driverInteractive` for the filtered source.
- Both apps receive the same filtered immutable source path from `flake/apps.nix`.

- [ ] **Step 1: Add the filtered source at app evaluation**

In `flake/apps.nix`, when `--impure` is enabled:

```nix
sourceRoot = builtins.toPath (builtins.getEnv "PWD");

dotfilesSource =
  assert builtins.pathExists (sourceRoot + "/flake.nix");
  pkgs.nix-gitignore.gitignoreSource [ ] sourceRoot;
```

Pass `dotfilesSource` to both build-installer and test-installer-e2e app constructors.

Add a fixture test proving an ordinary file is included while a path ignored by the fixture's `.gitignore` is absent from the filtered store path.

- [ ] **Step 2: Generate installer packages from host metadata**

Create `flake/installer.nix`. For every host satisfying:

```nix
host.systemTargetKind == "nixos"
host.system == system
```

derive the target name from the existing target naming rules using the host's default theme/session and target axes.

Construct `packages.installer-<host>` with:

```text
host registry key
target name
primaryAccountName
source = self.outPath
```

This module must not evaluate `nixosConfigurations.<target>`, so facter-less hosts still get installer packages when the flake is evaluated from the filtered snapshot.

- [ ] **Step 3: Build the ISO and reserve tty1**

`iso.nix` imports the pinned minimal installation CD module, derives EFI architecture, creates `mkInstallerScript`, and defines:

```nix
systemd.targets.getty.wants =
  lib.mkForce [ "autovt@tty2.service" ];

systemd.services."getty@tty1".enable = false;
systemd.services."autovt@tty1".enable = false;

systemd.services.dotfiles-installer = {
  wantedBy = [ "multi-user.target" ];
  path = [
    pkgs.nushell
    pkgs.nixos-facter
    pkgs.nix
    pkgs.nixos-install-tools
    pkgs.mkpasswd
    pkgs.util-linux
    pkgs.coreutils
    pkgs.systemd
  ];

  serviceConfig = {
    Type = "exec";
    ExecStart = lib.getExe installerScript;
    StandardInput = "tty-force";
    StandardOutput = "tty";
    StandardError = "tty";
    TTYPath = "/dev/tty1";
    TTYReset = true;
  };
};
```

Add `network-online.target` ordering only if the tested Nix fetch path requires it.

- [ ] **Step 4: Implement the thin generic build app**

`build.nu` accepts only `--host HOST` and executes:

```text
nix build path:<dotfilesSource>#installer-HOST
  --out-link <sourceRoot>/result/installer-HOST
```

Do not add a separate host registry validator; an invalid host naturally fails because the package does not exist.

Builder tests assert the immutable source path is used and no Git command is invoked.

- [ ] **Step 5: Add the lifecycle E2E**

Create `nix/tests/installer/e2e.nix` with `pkgs.testers.runNixOSTest`.
Expose its `driverInteractive` from `flake/installer.nix` as:

```text
packages.installer-e2e-driver
```

The E2E app builds that package from the same immutable source:

```text
nix build path:<dotfilesSource>#installer-e2e-driver
```

and executes its `bin/nixos-test-driver --no-interactive`.

The VM has UEFI, the actual installer ISO as CD media, one blank non-removable internal disk, and network access for locked Nix dependencies.

The test must prove:

```text
tty1 installer active; tty1 getty/autovt masked
tty1 -> tty2 -> tty1 keeps installer alive
password input completes
facter.json is generated
fixed Disko layout is created
nixos-install succeeds
fallback EFI loader exists
installer powers off
ISO is removed
installed disk reaches multi-user.target
password login and sudo succeed
disposable root data disappears after reboot
persistent data and dotfiles survive
```

- [ ] **Step 6: Wire deterministic and networked tests**

`nix flake check -L` includes structural checks plus the deterministic impermanence VM. It may construct the E2E driver closure but must not execute the network-capable lifecycle.

Expose:

```text
nix run --impure .#test-installer-e2e
```

to execute the lifecycle test outside the sandbox.

- [ ] **Step 7: Update operator documentation**

Document only the current workflow:

```text
edit dotfiles
→ nix run --impure .#build-installer -- --host HOST
→ write/attach result/installer-HOST
→ boot installer and enter password
→ wait for poweroff
→ remove media
→ boot installed disk
```

Explain that installer input is the current non-ignored filesystem snapshot and that `.#update` is outside this installer design.

- [ ] **Step 8: Run the full verification**

```bash
nix flake check -L
nix run --impure .#test-installer-e2e
nix run --impure .#build-installer -- --host aarch64-linux-a
test -e result/installer-aarch64-linux-a
```

If required virtualization is unavailable, report that limitation rather than weakening the E2E.

Do not boot the resulting ISO on the user's real machine.

- [ ] **Step 9: Commit**

```bash
git add nix/installer/iso.nix nix/flake/installer.nix nix/apps/build-installer nix/tests/installer/e2e.nix nix/apps/test-installer-e2e nix/flake/apps.nix nix/flake/default.nix nix/checks.nix README.org flake.nix
git commit -m "feat: add snapshot-based nixos installer"
```
