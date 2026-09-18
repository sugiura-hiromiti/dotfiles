# NixOS Impermanence Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build generic NixOS installation media from the current filtered dotfiles filesystem, generate facter on the target, install one fixed impermanent layout, and verify the lifecycle.

**Architecture:** During impure app evaluation, the current directory is filtered with `nix-gitignore` and frozen as a store path. The ISO copies that source writable, adds facter, evaluates the final configuration, validates one target disk, installs, and persists the same tree.

**Tech Stack:** NixOS/nixpkgs, flake-parts, Disko, nixos-facter, preservation, Nushell, nix-gitignore, systemd-boot, NixOS VM tests.

**Spec:** `docs/superpowers/specs/2026-09-18-nixos-impermanence-bootstrap-design.md`

## Global Constraints

- Build command: `nix run --impure .#build-installer -- --host HOST`.
- Source: `pkgs.nix-gitignore.gitignoreSource [ ] (builtins.toPath (builtins.getEnv "PWD"))`.
- Final NixOS configs require `facter.json`; installer packages do not.
- Installer Nix commands use `--no-update-lock-file`.
- Fixed storage: `dotfiles-system`, `@root`, `@nix`, `@persist`, `/dev/dotfiles-install-target`.
- Exactly one non-removable, non-hotplug whole disk is accepted.
- tty1 belongs to the installer; tty2 is diagnostic.
- EFI-variable writes stay disabled.
- Keep one impermanence VM and one installer E2E.
- Do not boot the ISO on the real machine.

**Executor note:** make newly created implementation files visible to ordinary Git-flake evaluation before importing them (for example `git add -N path`). This is development-only.

---

## File Structure

| Area | Files |
|---|---|
| Fixed installed state | `storage/layout.nix`, `storage/provisioning.nix`, `impermanence/{impermanence,ephemeral-root}.nix`, `configurations/nixos.nix` |
| Facter gating | `flake/{default,configurations,checks}.nix` |
| Installer transaction | `installer/{install.nu,script.nix}` |
| ISO/builder | `installer/iso.nix`, `flake/installer.nix`, `apps/build-installer/*` |
| Verification | `tests/nixos/impermanence-vm.nix`, `tests/installer/{runtime,e2e}.nix` |

---

### Task 1: Fix the Final NixOS Model

**Files:**
- Create: `nix/modules/nixos/features/storage/layout.nix`
- Modify: `nix/modules/nixos/features/storage/provisioning.nix`
- Delete: `nix/modules/nixos/features/storage/default.nix`
- Modify: `nix/modules/nixos/features/impermanence/{ephemeral-root,impermanence}.nix`
- Modify: `nix/configurations/nixos.nix`
- Modify: `nix/modules/nixos/default.nix`
- Modify: `nix/flake/{default,configurations,checks}.nix`
- Modify: `nix/tests/nixos/{storage-provisioning,impermanence,impermanence-vm}.nix`
- Delete: `nix/tests/nixos/{ephemeral-root,storage-provisioning-vm}.nix`
- Modify: `nix/checks.nix`

**Precondition:** the current production NixOS host has already been migrated to valid `facter.json`.

**Produces:**
- fixed storage constants;
- facter-only final NixOS targets;
- internal fixed root reset;
- one deterministic root-reset VM.

- [ ] **Step 1: Rewrite the structural tests**

`storage-provisioning.nix` must assert:

```nix
assert disk.device == "/dev/dotfiles-install-target";
assert disk.content.partitions.ESP.content.mountpoint == "/boot";
assert disk.content.partitions.system.label == "dotfiles-system";
assert disk.content.partitions.system.content.subvolumes ? "@root";
assert disk.content.partitions.system.content.subvolumes ? "@nix";
assert disk.content.partitions.system.content.subvolumes ? "@persist";
```

`impermanence.nix` must assert `/nix` and `/persist` are needed for boot and the root-reset unit uses `dotfiles-system` / `@root`.

Run both focused checks and confirm failure.

- [ ] **Step 2: Replace storage options with constants**

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

Rewrite `provisioning.nix` to declare the GPT/ESP/Btrfs layout from those constants. Remove the old storage option module and its import.

- [ ] **Step 3: Make root reset internal**

Remove the public `ephemeralRoot` options from `ephemeral-root.nix`. The initrd service uses the fixed layout and:

```text
blkid -t PARTLABEL=dotfiles-system -o device
```

It requires exactly one unique device before deleting/recreating `@root`. `impermanence.nix` imports this internal module and marks `/nix` and `/persist` needed for boot.

- [ ] **Step 4: Make constructed NixOS configs facter-only**

Each constructed NixOS target includes:

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

- [ ] **Step 5: Omit facter-less final targets**

Define:

```nix
nixosHostReady =
  hostName:
  builtins.pathExists (../profiles/hosts + "/${hostName}/facter.json");
```

Filter NixOS entries with it in `flake/configurations.nix` and `flake/checks.nix`. Home/Darwin targets are unchanged.

- [ ] **Step 6: Consolidate behavioral testing**

Keep only `impermanence-vm.nix` for boot/reboot behavior:

```text
fixed layout -> boot -> disposable + persistent markers
-> reboot -> disposable gone -> persistent survives -> @root exists
```

Delete the other two VM/root-reset tests and remove their check entries.

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

**Interface:**

```nix
mkInstallerScript {
  host;
  target;
  primaryAccount;
  source;
  efiArch;
}
```

Runtime source: `/run/dotfiles-installer/source`. Disk alias: `/dev/dotfiles-install-target`.

- [ ] **Step 1: Write transaction tests**

With fake external commands, cover:

```text
source copied writable
facter generated for host
one metadata eval uses path:/run/dotfiles-installer/source
all installer Nix commands use --no-update-lock-file
0 or >1 eligible disks abort before Disko
1 eligible disk creates the alias
Git and nix flake update are never invoked
```

Run the new `installer-runtime` check and confirm failure.

- [ ] **Step 2: Package the script**

`script.nix` substitutes the five immutable interface values into `install.nu`.

The ISO service will provide this PATH:

```nix
[
  pkgs.nushell
  pkgs.nixos-facter
  pkgs.nix
  pkgs.nixos-install-tools
  pkgs.mkpasswd
  pkgs.util-linux
  pkgs.coreutils
  pkgs.systemd
]
```

- [ ] **Step 3: Implement preparation and one metadata evaluation**

The script:

1. copies `source` to `/run/dotfiles-installer/source` and makes it writable;
2. prompts twice for a matching non-empty password and hashes it with yescrypt;
3. writes fresh `facter.json` for `host`;
4. evaluates the final config once with `--json --apply --no-update-lock-file`.

The apply result is:

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

Reject missing/non-integer UID/GID and empty home/group/hash paths.

Then build only `config.system.build.diskoScript` with
`--no-update-lock-file --no-link --print-out-paths`.

- [ ] **Step 4: Implement the destructive barrier**

Run:

```text
lsblk --json --output PATH,TYPE,RM,HOTPLUG
```

Require exactly one `TYPE=disk`, `RM=0`, `HOTPLUG=0` entry, then create:

```text
/dev/dotfiles-install-target -> selected disk
```

Nothing destructive occurs before this succeeds.

- [ ] **Step 5: Provision and install**

Run Disko; require `/mnt`, `/mnt/boot`, `/mnt/nix`, `/mnt/persist` mountpoints.

Write the password hash to `/mnt + hashedPasswordFile` with directory mode `0700` and file mode `0600`.

Run:

```bash
nixos-install \
  --root /mnt \
  --flake "path:/run/dotfiles-installer/source#$target" \
  --no-update-lock-file \
  --no-channel-copy \
  --no-root-password
```

- [ ] **Step 6: Persist and finish**

Require `/mnt/boot/EFI/BOOT/BOOT<ARCH>.EFI`.

Copy the writable source to `/mnt/persist + home + /dotfiles`, chown it to UID:GID, then `sync`, recursively unmount `/mnt`, verify unmounted, and `systemctl poweroff`.

Errors before completion exit non-zero without powering off.

- [ ] **Step 7: Verify and commit**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).installer-runtime
nix flake check -L
git add nix/installer/install.nu nix/installer/script.nix nix/tests/installer/runtime.nix nix/checks.nix
git commit -m "feat: add nixos installer transaction"
```

---

### Task 3: Add Builder, ISO, and Lifecycle E2E

**Files:**
- Create: `nix/installer/iso.nix`
- Create: `nix/flake/installer.nix`
- Create: `nix/apps/build-installer/{default.nix,build.nu,tests/run.sh}`
- Create: `nix/tests/installer/e2e.nix`
- Create: `nix/apps/test-installer-e2e/default.nix`
- Modify: `nix/flake/{apps,default}.nix`
- Modify: `nix/checks.nix`
- Modify: `README.org`, `flake.nix`

**Produces:**
- `packages.installer-<host>`;
- `packages.installer-e2e-driver`;
- `build-installer` and `test-installer-e2e` apps.

- [ ] **Step 1: Freeze the current filesystem during app evaluation**

In `flake/apps.nix`:

```nix
sourceRoot = builtins.toPath (builtins.getEnv "PWD");
dotfilesSource =
  assert builtins.pathExists (sourceRoot + "/flake.nix");
  pkgs.nix-gitignore.gitignoreSource [ ] sourceRoot;
```

Pass `sourceRoot` and `dotfilesSource` to both apps.

Add a tiny fixture check proving an ordinary file is present and an ignored file is absent from the filtered result.

- [ ] **Step 2: Generate installer packages**

For each NixOS host on the current system, derive its default target with the existing target naming rules and construct:

```text
packages.installer-HOST
```

using `host`, target, primary account, and `source = self.outPath`.

Do not evaluate the final `nixosConfigurations`; facter-less hosts must still produce installer packages when the filtered snapshot flake is evaluated.

- [ ] **Step 3: Build the ISO and own tty1**

`iso.nix` imports the minimal installation CD module, derives EFI architecture, calls `mkInstallerScript`, and configures:

```nix
systemd.targets.getty.wants = lib.mkForce [ "autovt@tty2.service" ];
systemd.services."getty@tty1".enable = false;
systemd.services."autovt@tty1".enable = false;

systemd.services.dotfiles-installer = {
  wantedBy = [ "multi-user.target" ];
  path = [ /* Task 2 runtime packages */ ];
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

Add network-online ordering only if required by tested Nix dependency fetching.

- [ ] **Step 4: Implement the thin build app**

`build.nu --host HOST` runs:

```text
nix build path:<dotfilesSource>#installer-HOST
  --out-link <sourceRoot>/result/installer-HOST
```

An invalid host fails because the package is absent. Builder tests assert the immutable source path is used and no Git command runs.

- [ ] **Step 5: Add the lifecycle driver**

`nix/tests/installer/e2e.nix` uses `pkgs.testers.runNixOSTest`. Export its `driverInteractive` as:

```text
packages.installer-e2e-driver
```

The E2E app builds that package from `path:<dotfilesSource>` and runs
`bin/nixos-test-driver --no-interactive`.

The VM uses UEFI, the actual installer ISO, one blank internal disk, and network access for locked dependencies.

Verify:

```text
tty1 installer active; tty1 gettys masked; tty2 usable
password flow completes
facter appears
fixed Disko layout is installed
fallback EFI loader exists
installer powers off
installed disk boots without ISO
password login + sudo work
root data resets; persistent data and dotfiles survive reboot
```

- [ ] **Step 6: Wire test execution**

`nix flake check -L` runs structural checks and the deterministic impermanence VM, but not the network-capable lifecycle.

Expose:

```text
nix run --impure .#test-installer-e2e
```

for the full E2E.

- [ ] **Step 7: Document and verify**

Document only:

```text
edit dotfiles
→ nix run --impure .#build-installer -- --host HOST
→ write/attach ISO
→ boot and enter password
→ poweroff
→ remove media
→ boot installed system
```

Then run:

```bash
nix flake check -L
nix run --impure .#test-installer-e2e
nix run --impure .#build-installer -- --host aarch64-linux-a
test -e result/installer-aarch64-linux-a
```

If virtualization is unavailable, report it rather than weakening the E2E. Do not boot the ISO on the real machine.

- [ ] **Step 8: Commit**

```bash
git add nix/installer/iso.nix nix/flake/installer.nix nix/apps/build-installer nix/tests/installer/e2e.nix nix/apps/test-installer-e2e nix/flake/apps.nix nix/flake/default.nix nix/checks.nix README.org flake.nix
git commit -m "feat: add snapshot-based nixos installer"
```
