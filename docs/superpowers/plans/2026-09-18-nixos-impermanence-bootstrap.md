# NixOS Impermanence Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build same-system NixOS installation media from the current dotfiles filesystem snapshot, generate facter on the target, install one fixed impermanent layout, and verify the lifecycle.

**Architecture:** Every operator/test command that evaluates this repository uses an explicit `path:` flake reference. Nix freezes the current directory as `self.outPath`; the builder, ISO, runtime installer, and E2E all use that same immutable snapshot. The ISO copies it writable, adds facter, evaluates the final configuration, validates one target disk, installs, and persists the same tree.

**Tech Stack:** NixOS/nixpkgs, flake-parts, Disko, nixos-facter, preservation, Nushell, systemd-boot, NixOS VM tests.

**Spec:** `docs/superpowers/specs/2026-09-18-nixos-impermanence-bootstrap-design.md`

## Global Constraints

- Build command: `nix run path:.#build-installer -- --host HOST`.
- Check command: `nix flake check -L path:.`.
- `self.outPath` is the installer source snapshot; do not create another source snapshot/filter layer.
- `.git` may be physically included by `path:`; installer code must treat it as inert data and never inspect Git state.
- `host` always means registry key; `hostName` means OS/network hostname.
- Installer target uses `runtime.defaultTheme` and `runtime.defaultSession`, never runtime-list order.
- Builder supports declared NixOS hosts whose `system` matches the current `perSystem` system.
- Final NixOS configs require `facter.json`; installer packages do not.
- Installer Nix commands use `--no-update-lock-file`.
- Fixed storage: `dotfiles-system`, `@root`, `@nix`, `@persist`, `/dev/dotfiles-install-target`.
- Exactly one non-removable, non-hotplug whole disk is accepted.
- tty1 belongs to the installer; tty2 is diagnostic.
- EFI-variable writes stay disabled.
- Keep one impermanence VM and one installer E2E.
- Do not boot the ISO on the real machine.

---

## File Structure

| Area | Files |
|---|---|
| Final installed state | `storage/layout.nix`, `storage/provisioning.nix`, `impermanence/{impermanence,ephemeral-root}.nix`, `configurations/nixos.nix`, production host `nixos.nix` |
| Facter gating | `flake/{default,configurations,checks}.nix`, `lib/targets.nix`, `checks.nix` |
| Installer transaction | `installer/{install.nu,script.nix}`, `tests/installer/runtime.nix` |
| ISO/builder | `installer/iso.nix`, `flake/installer.nix`, `apps/build-installer/*` |
| Verification | `tests/nixos/impermanence-vm.nix`, `tests/installer/e2e.nix` |

---

### Task 1: Fix the Final NixOS Model

**Files:**
- Create: `nix/modules/nixos/features/storage/layout.nix`
- Modify: `nix/modules/nixos/features/storage/provisioning.nix`
- Delete: `nix/modules/nixos/features/storage/default.nix`
- Modify: `nix/modules/nixos/features/impermanence/{ephemeral-root,impermanence}.nix`
- Modify: `nix/configurations/nixos.nix`
- Modify: `nix/modules/nixos/default.nix`
- Modify: `nix/profiles/hosts/aarch64-linux-a/nixos.nix`
- Modify: `nix/flake/{default,configurations,checks}.nix`
- Modify: `nix/lib/targets.nix`
- Modify: `nix/checks.nix`
- Modify: `nix/tests/nixos/{storage-provisioning,impermanence,impermanence-vm}.nix`
- Delete: `nix/tests/nixos/{ephemeral-root,storage-provisioning-vm}.nix`

**Produces:**
- fixed storage constants;
- facter-only final NixOS targets;
- internal fixed root reset;
- effective primary-user ownership available from final config;
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

Run both focused checks through `path:.` and confirm failure.

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

- [ ] **Step 4: Centralize universal final-system policy**

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

In `nix/profiles/hosts/aarch64-linux-a/nixos.nix`, remove local
`hardware.facter.reportPath`, all `fileSystems`, and `swapDevices`.
Keep only host-specific policy such as performance tuning.

- [ ] **Step 5: Gate final configurations from one ready-entry source of truth**

In `flake/default.nix`, define readiness once:

```nix
nixosHostReady =
  host:
  builtins.pathExists (../profiles/hosts + "/${host}/facter.json");

readyNixosTargetEntries =
  lib.filter
    (entry: nixosHostReady entry.config.host)
    (targets.mkTargetConfigEntries "nixos");
```

Do not independently re-run the readiness predicate in `flake/configurations.nix`
and `flake/checks.nix`. Pass the same `readyNixosTargetEntries` to both.

Current `mkTargetConfigs` internally enumerates all target entries, so extend
`nix/lib/targets.nix` with an entry-based constructor while preserving the
existing wrapper:

```nix
mkTargetConfigsFromEntries =
  target: entries: mkConf:
  lib.listToAttrs (
    map (entry: {
      inherit (entry) name;
      value = mkConf entry.config;
    }) (assertUniqueTargetNames target entries)
  );

mkTargetConfigs =
  target: mkConf:
  mkTargetConfigsFromEntries target (mkTargetConfigEntries target) mkConf;
```

Export final NixOS configurations from `readyNixosTargetEntries` through
`mkTargetConfigsFromEntries`.

In `flake/checks.nix`, derive the per-system ready entries from that same list:

```nix
nixosTargetEntries =
  lib.filter (entry: entry.config.system == system) readyNixosTargetEntries;

targetConfigNames.nixos = map (entry: entry.name) nixosTargetEntries;
```

Do not use the unfiltered `targetConfigNamesForSystem "nixos" system` for NixOS
build checks. This same `nixosTargetEntries` feeds embedded-Home-Manager checks
and the primary-user ownership checks, so no check can dereference a
`self.nixosConfigurations` entry that readiness filtering removed.

Add an evaluation check for each ready NixOS target asserting the primary user's effective `group` is non-empty and `config.users.groups.${group}.gid` is an integer. Use the evaluated NixOS values; do not add group metadata.

- [ ] **Step 6: Keep one behavioral impermanence VM**

`impermanence-vm.nix` proves:

```text
fixed layout -> boot -> disposable + persistent markers
-> reboot -> disposable gone -> persistent survives -> @root exists
```

Delete `storage-provisioning-vm.nix` and the standalone `ephemeral-root.nix` test.

- [ ] **Step 7: Verify and commit**

```bash
nix flake check -L path:.
git add -A nix/modules/nixos nix/configurations/nixos.nix nix/profiles/hosts/aarch64-linux-a/nixos.nix nix/flake nix/lib/targets.nix nix/tests/nixos nix/checks.nix
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
metadata contains home, integer UID, non-empty group, integer GID, password path
all installer Nix commands use --no-update-lock-file
0 or >1 eligible disks abort before Disko
fake lsblk JSON uses boolean rm/hotplug values
1 eligible disk creates the alias
nix flake update is never invoked
```

Run the new `installer-runtime` check through `path:.` and confirm failure.

- [ ] **Step 2: Package the script**

`script.nix` substitutes `host`, `target`, `primaryAccount`, `source`, and `efiArch` into `install.nu`.

The ISO service in Task 3 provides:

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

- [ ] **Step 3: Implement reversible preparation and one metadata evaluation**

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

where `user = config.users.users.<primaryAccount>`.

Reject missing/non-integer UID/GID and empty home/group/hash paths. Then build only `config.system.build.diskoScript` with `--no-update-lock-file --no-link --print-out-paths`.

- [ ] **Step 4: Implement the destructive barrier**

Run:

```text
lsblk --json --output PATH,TYPE,RM,HOTPLUG
```

Parse the JSON and require exactly one entry satisfying:

```text
type == "disk"
rm == false
hotplug == false
```

`RM` and `HOTPLUG` are JSON booleans, not numeric 0/1 values. Then create:

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
nix build -L path:.#checks.$(nix eval --raw --impure --expr builtins.currentSystem).installer-runtime
nix flake check -L path:.
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
- same-system `packages.installer-<host>`;
- `packages.installer-e2e-driver`;
- `build-installer` and `test-installer-e2e` apps.

- [ ] **Step 1: Pass the path snapshot directly to the apps**

In `flake/apps.nix`, pass:

```nix
source = self.outPath;
```

to `build-installer`.

Do not read `PWD`, run an impure evaluation, apply an ignore policy, or create another source path.

Add a check that the builder package embeds exactly `self.outPath` as its source argument.

- [ ] **Step 2: Generate same-system installer packages with an exact default target**

In `flake/installer.nix`, select hosts with:

```nix
host.systemTargetKind == "nixos"
&& host.system == system
```

For each host derive:

```nix
targetNames.mkSystemTargetName {
  inherit (host) targetHost;
  inherit (host.runtime) targetAxes;
  themeName = host.runtime.defaultTheme;
  sessionName = host.runtime.defaultSession;
}
```

For `aarch64-linux-a`, assert:

```text
aarch64-linux-a--theme-light--session-gui
```

Add a regression that reverses the theme/session lists while keeping declared defaults unchanged and verifies the target name remains unchanged.

Construct `packages.installer-<host>` with `source = self.outPath`. Do not evaluate the final NixOS target.

- [ ] **Step 3: Build the ISO and own tty1**

`iso.nix` imports the minimal installation CD module, derives EFI architecture, calls `mkInstallerScript`, and explicitly enables the Nix CLI features used by the runtime installer:

```nix
nix.settings.experimental-features = [
  "nix-command"
  "flakes"
];

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

Add an evaluation check for the ISO configuration that asserts both
`nix-command` and `flakes` are present in
`nix.settings.experimental-features`.

- [ ] **Step 4: Implement the thin build app**

`build.nu --host HOST` runs:

```text
nix build path:<source>#installer-HOST
  --out-link result-installer-HOST
```

where `source` is the `self.outPath` baked into the app during
`nix run path:.#build-installer`.

Use the flat `result-installer-HOST` name rather than treating the conventional
`result` out-link as a directory. A pre-existing ordinary `result -> /nix/store/...`
symlink must not affect installer builds.

An invalid or non-same-system host fails because the package is absent.

- [ ] **Step 5: Add the lifecycle E2E**

`nix/tests/installer/e2e.nix` uses `pkgs.testers.runNixOSTest`; expose its `driverInteractive` as `packages.installer-e2e-driver`.

`nix run path:.#test-installer-e2e` executes that driver's
`bin/nixos-test-driver --no-interactive` from the same `path:.` source snapshot.

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

- [ ] **Step 6: Document and verify**

Document:

```text
edit dotfiles
→ nix run path:.#build-installer -- --host HOST
→ write/attach ISO
→ boot and enter password
→ poweroff
→ remove media
→ boot installed system
```

Then run:

```bash
nix flake check -L path:.
nix run path:.#test-installer-e2e
nix run path:.#build-installer -- --host aarch64-linux-a
test -e result-installer-aarch64-linux-a
```

If virtualization is unavailable, report it rather than weakening the E2E. Do not boot the ISO on the real machine.

- [ ] **Step 7: Commit**

```bash
git add nix/installer/iso.nix nix/flake/installer.nix nix/apps/build-installer nix/tests/installer/e2e.nix nix/apps/test-installer-e2e nix/flake/apps.nix nix/flake/default.nix nix/checks.nix README.org flake.nix
git commit -m "feat: add path-based nixos installer"
```
