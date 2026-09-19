# NixOS Impermanence Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build same-system NixOS installation media from the current dotfiles filesystem snapshot, generate facter on the target, install one fixed impermanent layout, and verify the lifecycle.

**Architecture:** Every operator/test command that evaluates this repository uses an explicit `path:` flake reference. Nix freezes the current directory as the immutable base snapshot `self.outPath`; the builder and ISO consume that base directly. At runtime each installer service invocation creates exactly one writable host-materialized tree from that base, adds fresh `facter.json`, then stops mutating it. All final NixOS evaluation/build/install operations use `path:/run/dotfiles-installer/source`, so repeated evaluations are permitted but are derived from the same host-materialized contents.

**Tech Stack:** NixOS/nixpkgs, flake-parts, Disko, nixos-facter, preservation, Nushell, systemd-boot, NixOS VM tests.

**Spec:** `docs/superpowers/specs/2026-09-18-nixos-impermanence-bootstrap-design.md`

## Global Constraints

- Build command: `nix run path:.#build-installer -- --host HOST`.
- Universal evaluation command: `nix flake check --no-build path:.`.
- Full VM-backed check command: `nix flake check -L path:.` on a builder advertising the `kvm` system feature. KVM-backed checks are a separate lifecycle gate, not a universal requirement on non-KVM machines.
- `self.outPath` is the immutable base installer snapshot. Each runtime invocation may create exactly one host-materialized copy by adding fresh facter data; do not create any other source reconstruction, refetch, or filter layer.
- After fresh `facter.json` is written, `/run/dotfiles-installer/source` is logically immutable: all later Nix evaluation/build/install commands use that same tree without modifying it.
- `.git` may be physically included by `path:`; installer code must treat it as inert data and never inspect Git state.
- `host` always means registry key; `hostName` means OS/network hostname.
- Installer target uses `runtime.defaultTheme` and `runtime.defaultSession`, never runtime-list order.
- Builder supports declared NixOS hosts whose `system` matches the current `perSystem` system.
- Final NixOS configs require `facter.json`; installer packages do not.
- Installer Nix commands use `--no-update-lock-file`.
- Generated CI commands that evaluate this repository also use explicit `path:.` flake operands; there is no CI exception to the source contract.
- The destructive barrier proves final metadata evaluation, Disko-script realization, and target-disk validation only. It intentionally does not pre-realize `system.build.toplevel`; `nixos-install --flake` may still fail after Disko because of dependency/substitution/system-build or bootloader errors.
- Fixed storage: `dotfiles-system`, `@root`, `@nix`, `@persist`, `/dev/dotfiles-install-target`.
- Exactly one eligible target disk is accepted, where eligible means a whole disk with `rm == false` and `hotplug == false`. This predicate does not prove physical/internal attachment; the operator/environment must ensure the sole eligible disk is the intended target.
- tty1 belongs to the installer; tty2 is diagnostic.
- EFI-variable writes stay disabled.
- Keep one impermanence VM and one installer E2E.
- Do not boot the ISO on the real machine.

---

## File Structure

| Area | Files |
|---|---|
| Final installed state | `storage/layout.nix`, `storage/provisioning.nix`, `impermanence/{impermanence,ephemeral-root}.nix`, `configurations/nixos.nix`, production host `nixos.nix` |
| Facter gating | `lib/hosts.nix`, `flake/{default,configurations,checks,ci}.nix`, `configurations/nixos.nix`, `lib/targets.nix`, `ci/default.nix`, `checks.nix` |
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
- Modify: `nix/flake/{default,configurations,checks,ci}.nix`
- Modify: `nix/lib/hosts.nix`
- Modify: `nix/lib/targets.nix`
- Modify: `nix/ci/default.nix`
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

`impermanence.nix` must assert `/nix` and `/persist` are needed for boot, the root-reset unit uses `dotfiles-system` / `@root`, and the initrd unit that performs discovery/reset has explicit executable dependencies on `pkgs.util-linux` and `pkgs.btrfs-progs` through its service-local `path`.

The test must fail if `blkid` is only available in the stage-2 system or installer ISO; it must validate the installed system's initrd service environment.

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

Remove the public `ephemeralRoot` options from `ephemeral-root.nix`. The initrd root-reset service uses the fixed layout and:

```text
blkid -t PARTLABEL=dotfiles-system -o device
```

The installed initrd must provide every executable that service invokes. Declare the dependencies on the initrd service itself rather than relying on the installer ISO or incidental initrd contents:

```nix
boot.initrd.systemd.services.<root-reset-unit>.path = [
  pkgs.util-linux
  pkgs.btrfs-progs
];
```

This guarantees `blkid` and `btrfs` are available in that unit's initrd execution environment. Prefer this service-local `path` over a global `boot.initrd.systemd.extraBin` unless another initrd consumer genuinely needs the same tools.

The service requires exactly one unique device before deleting/recreating `@root`. `impermanence.nix` imports this internal module and marks `/nix` and `/persist` needed for boot.

- [ ] **Step 4: Centralize universal final-system policy**

Pass both `disko` and the shared `facterPathForHost` helper into `configurations/nixos.nix` from `flake/default.nix`.

In `configurations/nixos.nix`, every constructed NixOS target includes:

```nix
{ hardware.facter.reportPath = facterPathForHost config.host; }
(import ../modules/nixos/features/storage/provisioning.nix { inherit disko; })
{
  dotfiles.features.preservation.enable = true;
  dotfiles.features.impermanence.enable = true;
  users.mutableUsers = false;
  users.users.${config.primaryAccountName}.hashedPasswordFile =
    "/persist/etc/dotfiles/password-${config.primaryAccountName}.hash";
}
(args: {
  assertions = [
    {
      assertion = args.config.boot.loader.systemd-boot.enable;
      message = "installer-compatible NixOS targets require systemd-boot";
    }
    {
      assertion = !args.config.boot.loader.efi.canTouchEfiVariables;
      message = "installer-compatible NixOS targets must not write EFI variables";
    }
    {
      assertion =
        args.config.users.users.${config.primaryAccountName}.isNormalUser;
      message = "installer primary account must remain a normal user";
    }
    {
      assertion =
        builtins.elem "wheel"
          args.config.users.users.${config.primaryAccountName}.extraGroups;
      message = "installer primary account must remain in wheel";
    }
    {
      assertion = args.config.security.sudo.enable;
      message = "installer-compatible NixOS targets require sudo";
    }
  ];
})
```

Keep the baseline boot module's `mkDefault` values composable; the constructor
assertions enforce the effective installer contract after all modules merge.

In `nix/profiles/hosts/aarch64-linux-a/nixos.nix`, remove local
`hardware.facter.reportPath`, all `fileSystems`, and `swapDevices`.
Keep only host-specific policy such as performance tuning.

- [ ] **Step 5: Gate final configurations from one ready-entry source of truth**

Make the repository-relative host-directory location the source of truth.

In `flake/default.nix`, construct the host registry from one relative directory and the repository source root:

```nix
hostDirRelative = "nix/profiles/hosts";

hostRegistry = import ../lib/hosts.nix {
  inherit lib runtimeContexts hostDirRelative;
  sourceRoot = ../..;
};
```

In `nix/lib/hosts.nix`, derive registry discovery plus both facter helpers from that same value:

```nix
hostDir = sourceRoot + "/${hostDirRelative}";

facterRelativePathForHost =
  host:
  "${hostDirRelative}/${host}/facter.json";

facterPathForHost =
  host:
  sourceRoot + "/${facterRelativePathForHost host}";
```

Export both helpers. In `flake/default.nix`, pass `facterPathForHost` to
`configurations/nixos.nix`, pass `facterRelativePathForHost` to installer
package construction, and define readiness only in terms of the absolute helper:

```nix
inherit (hostRegistry)
  hosts
  hostNames
  facterRelativePathForHost
  facterPathForHost
  ;

nixosHostReady =
  host:
  builtins.pathExists (facterPathForHost host);

readyNixosTargetEntries =
  lib.filter
    (entry: nixosHostReady entry.config.host)
    (targets.mkTargetConfigEntries "nixos");
```

Do not independently reconstruct `nix/profiles/hosts/<host>/facter.json`
anywhere else. Registry discovery, readiness, `hardware.facter.reportPath`,
and the runtime installer destination must all derive from
`hostDirRelative`/the exported helpers. Do not independently re-run the
readiness predicate in `flake/configurations.nix` and `flake/checks.nix`;
pass the same `readyNixosTargetEntries` to both.

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

Propagate the same readiness contract into CI. Pass `readyNixosTargetEntries`
through `flake/ci.nix` into `nix/ci/default.nix`. Keep Home Manager and Darwin
target discovery unchanged.

The representative Linux NixOS target is optional. A declared host without
`facter.json` is a supported bootstrap state, so zero matching ready entries
must return `null` rather than assert:

```nix
optionalDefaultTargetFromEntries =
  target: hostKey: entries:
  let
    host = hosts.${hostKey};
    matches = lib.filter (
      entry:
      entry.config.host == hostKey
      && entry.config.themeName == host.runtime.defaultTheme
      && entry.config.sessionName == host.runtime.defaultSession
    ) entries;
  in
  if matches == [ ] then
    null
  else
    assert lib.assertMsg (builtins.length matches == 1)
      "Expected at most one ready default ${target} target for ${hostKey}";
    (lib.head matches).name;

linuxNixosTarget =
  optionalDefaultTargetFromEntries "nixos" linuxHost readyNixosTargetEntries;
```

Keep shared CI jobs structurally present so existing `needs` relationships stay
valid. Conditionally include only the NixOS-specific evaluation step and
NixOS-specific smoke-build argument when `linuxNixosTarget != null`. The Linux
Home Manager smoke check and Darwin jobs remain unconditional.

Any generated CI step that dereferences `nixosConfigurations.${linuxNixosTarget}`
or `checks.<system>.build-nixos-${linuxNixosTarget}` must therefore both:

1. originate from the facter-ready set; and
2. be omitted when no facter-ready representative exists.

Convert every generated CI command that evaluates this repository to an explicit
`path:.` flake operand. At minimum:

```bash
nix eval --raw "path:.#nixosConfigurations...."
nix build "path:.#checks...." --no-write-lock-file
nix flake check path:. --no-write-lock-file --print-build-logs
nix build "path:.#checks.${linuxPlatform}.deadnix" --no-write-lock-file
nix build "path:.#checks.${linuxPlatform}.statix" --no-write-lock-file
nix fmt path:. -- --ci
nix run path:.#render-workflows
```

Commands such as `nix --version` and `nix store info` do not evaluate this
repository and need no flake operand.

Add two CI/readiness regressions:

- with `readyNixosTargetEntries = [ ]`, CI configuration still evaluates/renders
  and contains no NixOS-config/check dereference;
- generated workflows contain no repository-evaluating shorthand `.#...`
  references.

Task 3 adds the complementary bootstrap regression proving a declared,
facter-less NixOS host still receives an installer package/app.

Add evaluation regressions proving that, for every ready NixOS target:

- readiness is determined by `builtins.pathExists (facterPathForHost entry.config.host)`;
- the resulting `hardware.facter.reportPath` equals `facterPathForHost entry.config.host` exactly; and
- `facterRelativePathForHost entry.config.host` is the relative path baked into the corresponding installer package/script.

Also assert the primary user's effective `group` is non-empty, `config.users.groups.${group}.gid` is an integer, `isNormalUser == true`, `"wheel"` is present in the effective `extraGroups`, and `config.security.sudo.enable == true`. Use the evaluated NixOS values; do not add duplicate account metadata.

- [ ] **Step 6: Keep one behavioral impermanence VM**

`impermanence-vm.nix` proves:

```text
fixed layout -> boot -> disposable + persistent markers
-> reboot -> disposable gone -> persistent survives -> @root exists
```

Delete `storage-provisioning-vm.nix` and the standalone `ephemeral-root.nix` test.

- [ ] **Step 7: Verify and commit**

```bash
nix flake check --no-build path:.
# Build/run non-VM checks on any supported builder.
# Run the VM-backed impermanence check only on a builder with system feature "kvm".
nix flake check -L path:.  # KVM-capable builder
git add -A nix/modules/nixos nix/configurations/nixos.nix nix/profiles/hosts/aarch64-linux-a/nixos.nix nix/flake nix/lib/hosts.nix nix/lib/targets.nix nix/ci nix/tests/nixos nix/checks.nix
git commit -m "refactor: fix nixos bootstrap model"
```

Do not set `requiredFeatures.kvm = false` merely to make this gate runnable on
a non-KVM builder. A non-KVM machine reports the lifecycle gate unavailable;
it does not redefine the test.

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
  facterRelativePath;
  efiArch;
}
```

Runtime source: `/run/dotfiles-installer/source`. Disk alias: `/dev/dotfiles-install-target`.

- [ ] **Step 1: Write transaction tests**

With fake external commands, cover:

```text
each invocation recreates /run/dotfiles-installer/source from the immutable base
a stale /dev/dotfiles-install-target symlink is removed before disk discovery
a non-symlink object at /dev/dotfiles-install-target aborts safely
facter is written exactly to /run/dotfiles-installer/source + facterRelativePath
metadata eval uses path:/run/dotfiles-installer/source
metadata contains absolute safe home, integer UID, non-empty group, integer GID, exact password path, isNormalUser, effective extraGroups, and sudoEnabled
hashedPasswordFile must equal /persist/etc/dotfiles/password-<primary>.hash
home rejects relative, root, and '..' traversal paths
all installer Nix commands use --no-update-lock-file
0 or >1 eligible target disks abort before Disko
fake lsblk JSON uses boolean rm/hotplug values
1 eligible target disk creates the alias; RM/HOTPLUG is never described or tested as proof of physical/internal attachment
run #1 fails before Disko -> run #2 recreates clean transaction state and succeeds
nix flake update is never invoked
```

Run the new `installer-runtime` check through `path:.` and confirm failure.

- [ ] **Step 2: Package the script**

`script.nix` substitutes `host`, `target`, `primaryAccount`, `source`, `facterRelativePath`, and `efiArch` into `install.nu`. `facterRelativePath` is supplied by `facterRelativePathForHost host`; `install.nu` never reconstructs the repository-relative host/facter location.

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

- [ ] **Step 3: Implement reversible preparation and metadata evaluation**

Each service invocation starts a fresh transaction before any destructive work:

1. if `/dev/dotfiles-install-target` exists and is a symlink, remove it; if that
   path exists as anything else, abort;
2. remove and recreate only the installer-owned runtime source state under
   `/run/dotfiles-installer`;
3. copy immutable `source` to `/run/dotfiles-installer/source` and make it
   writable;
4. prompt twice for a matching non-empty password and hash it with yescrypt;
5. create the parent directory for `facterRelativePath` inside `/run/dotfiles-installer/source` and write fresh facter output exactly to `/run/dotfiles-installer/source + facterRelativePath`;
6. evaluate final-config metadata with `--json --apply --no-update-lock-file`
   from `path:/run/dotfiles-installer/source`.

The apply result is metadata only:

```nix
{
  home = user.home;
  uid = user.uid;
  group = user.group;
  gid = config.users.groups.${user.group}.gid;
  hashedPasswordFile = user.hashedPasswordFile;
  isNormalUser = user.isNormalUser;
  extraGroups = user.extraGroups;
  sudoEnabled = config.security.sudo.enable;
}
```

where `user = config.users.users.<primaryAccount>`.

Before Disko, validate:

- UID and GID are integers;
- `group` is non-empty;
- `home` is an absolute normalized path, is not `/`, and contains no `..`
  traversal component;
- `hashedPasswordFile` is exactly `/persist/etc/dotfiles/password-<primaryAccount>.hash`;
- `isNormalUser == true`;
- `"wheel"` is present in effective `extraGroups`; and
- `sudoEnabled == true`.

Do not merely accept arbitrary non-empty destination strings. These checks make
the later writes to `/mnt/persist + home + /dotfiles` and
`/mnt + hashedPasswordFile` consequences of the declared policy rather than
unvalidated module output.

From the moment fresh `facter.json` is written, do not modify
`/run/dotfiles-installer/source`. Later Disko realization and
`nixos-install --flake` may evaluate the final configuration again; every such
operation must use the same `path:/run/dotfiles-installer/source`
host-materialized tree and `--no-update-lock-file`.

Then build only `config.system.build.diskoScript` with
`--no-update-lock-file --no-link --print-out-paths`.

A failure before Disko must leave the service safe to invoke again: the next
invocation discards stale transaction-owned runtime state and starts again from
the immutable base snapshot.

- [ ] **Step 4: Implement the destructive barrier**

Run:

```text
lsblk --json --output PATH,TYPE,RM,HOTPLUG
```

Parse the JSON and require exactly one **eligible target disk** satisfying:

```text
type == "disk"
rm == false
hotplug == false
```

`RM` and `HOTPLUG` are JSON booleans, not numeric 0/1 values. This predicate is only the installer's eligibility filter; it does not establish that the device is physically internal. The supported environment must ensure the sole eligible disk is the intended installation target. Then create:

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

This deliberately realizes the final `system.build.toplevel` in the target
store after Disko rather than pre-realizing it in the live ISO store. Therefore
dependency/substitution/system-build and bootloader failures can still occur
after the target disk has been modified. That is an accepted resource/safety
tradeoff, not part of the pre-Disko barrier guarantee.

- [ ] **Step 6: Persist and finish**

Require `/mnt/boot/EFI/BOOT/BOOT<ARCH>.EFI`.

Copy the writable source to `/mnt/persist + home + /dotfiles`, chown it to UID:GID, then `sync`, recursively unmount `/mnt`, verify unmounted, and `systemctl poweroff`.

Errors before completion exit non-zero without powering off.

- [ ] **Step 7: Verify and commit**

```bash
nix build -L path:.#checks.$(nix eval --raw --impure --expr builtins.currentSystem).installer-runtime
nix flake check --no-build path:.
# Run full nix flake check only on a KVM-capable builder.
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

Construct `packages.installer-<host>` with `source = self.outPath` and `facterRelativePath = facterRelativePathForHost host`. Do not evaluate the final NixOS target. Add a regression that moving/changing `hostDirRelative` changes both `facterPathForHost` and the installer-baked relative destination consistently.

Add a bootstrap regression with a declared same-system NixOS host but no
facter-ready final configuration. It must still produce/evaluate
`packages.installer-<host>` and the `build-installer` app, while the optional
representative NixOS CI steps remain absent.

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
  wants = [ "network-online.target" ];
  after = [ "network-online.target" ];
  path = [ /* Task 2 runtime packages */ ];
  serviceConfig = {
    Type = "exec";
    ExecStart = lib.getExe installerScript;
    RuntimeDirectory = "dotfiles-installer";
    RuntimeDirectoryMode = "0700";
    StandardInput = "tty-force";
    StandardOutput = "tty";
    StandardError = "tty";
    TTYPath = "/dev/tty1";
    TTYReset = true;
  };
};
```

Add evaluation checks for the ISO configuration that assert:

- both `nix-command` and `flakes` are present in `nix.settings.experimental-features`;
- `dotfiles-installer` both wants and starts after `network-online.target`.

`network-online.target` is startup ordering, not proof of Internet reachability.
If a locked dependency fetch fails before Disko, the installer must fail
non-destructively, leave tty2 available for networking repair, and print a
concrete recovery instruction such as restarting
`dotfiles-installer.service` after connectivity is fixed. The fresh-transaction
rules in Task 2 make that pre-Disko retry deterministic. Failures after Disko are
outside the non-destructive retry guarantee.

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

The VM uses UEFI, the actual installer ISO, and one blank eligible target disk.
The lifecycle E2E is **offline/hermetic**: it must not require public Internet,
DNS, or a default route. `runNixOSTest` network isolation is part of the test
contract, not something to work around.

Arrange all locked flake input source paths and install-time store content needed
by the test through declared Nix dependencies. The implementation may either:

- embed/prepopulate the required test-only store paths/closures so the installer
  can evaluate and install offline; or
- expose them through a cache/service reachable only on the isolated NixOS-test
  network.

Whichever mechanism is chosen, the test must not contact public substituters or
source hosts. Keep connectivity-failure/restart behavior in the fake-command
runtime test from Task 2 rather than depending on real Internet failure here.

Verify:

```text
no public default route/DNS dependency is required for installation
tty1 installer active; tty1 gettys masked; tty2 usable
installer starts after network-online.target
password flow completes
facter appears at the baked facterRelativePath
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

Then run the universal gate on every supported builder:

```bash
nix flake check --no-build path:.
# Build/run the non-VM checks explicitly.
nix run path:.#build-installer -- --host aarch64-linux-a
test -e result-installer-aarch64-linux-a
```

On a builder advertising the `kvm` system feature, run the lifecycle gate:

```bash
nix flake check -L path:.
nix run path:.#test-installer-e2e
```

If KVM is unavailable, report the VM/lifecycle gate as unavailable rather than
setting `requiredFeatures.kvm = false`, removing the checks, or treating the
universal gate as if it had exercised the lifecycle. Do not boot the ISO on the
real machine.

- [ ] **Step 7: Commit**

```bash
git add nix/installer/iso.nix nix/flake/installer.nix nix/apps/build-installer nix/tests/installer/e2e.nix nix/apps/test-installer-e2e nix/flake/apps.nix nix/flake/default.nix nix/checks.nix README.org flake.nix
git commit -m "feat: add path-based nixos installer"
```
