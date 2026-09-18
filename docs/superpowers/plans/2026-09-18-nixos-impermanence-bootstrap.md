
# NixOS Impermanence Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Build a host-specific unattended NixOS installer that records hardware facts, provisions the Disko Btrfs impermanence layout, installs from a local Git commit, and leaves .#update as the non-destructive steady-state updater.

**Architecture:** Split bootstrap from steady-state operation. Host metadata and a clean Git commit are sufficient to build a host-specific installer ISO; the ISO regenerates facter.json, updates flake.lock, evaluates the resolved NixOS target, selects exactly one safe target disk, then runs Disko and nixos-install. The installed system uses nixos-facter for hardware, Disko for filesystem topology, preservation for persistent state, and the existing initrd ephemeral-root module for root reset.

**Tech Stack:** NixOS/nixpkgs, flake-parts, Disko, nixos-facter, preservation, Nushell, systemd, Git, NixOS VM tests.

**Spec:** docs/superpowers/specs/2026-09-18-nixos-impermanence-bootstrap-design.md

## Global Constraints

- The dotfiles repository state on the ISO build machine is the source of truth.
- Host ISO builds require a clean Git working tree and embed the exact committed HEAD as Git history.
- There is one custom installer ISO per host.
- The installer regenerates facter.json on every install.
- The installer may run nix flake update; facter.json and flake.lock are committed locally before destructive provisioning.
- The installer never pushes.
- Network access may be required for Nix fetches and substitutes.
- Disko is the only owner of the installed filesystem topology.
- Impermanence owns only ephemeral-root runtime behavior.
- Preservation policy remains narrow; do not broaden the preservation list in this project.
- Default disk selection is the only internal, non-removable whole disk.
- Zero or multiple eligible disks fail closed unless a host-specific explicit disk override exists.
- The installer must exclude the live installer medium.
- Reinstall means a complete target-disk wipe; existing /persist and target-machine Git state are not recovered.
- nix run .#update remains non-destructive and does not bootstrap or repartition machines.
- A local branch ahead of its remote is a valid managed-machine state.
- The final installed host configuration is evaluated only after hardware facts exist.
- A bootstrap ISO must remain buildable before hardware facts exist.

---

## File Structure

The implementation should converge on these boundaries:

~~~text
nix/
├── installer/
│   ├── build.nix
│   ├── default.nix
│   ├── iso.nix
│   ├── script.nix
│   ├── install.nu
│   └── disk-selector.nu
├── apps/
│   ├── build-installer/
│   │   ├── default.nix
│   │   ├── script.nix
│   │   └── build.nu
│   └── update/
├── lib/
│   ├── hosts.nix
│   └── stable-uuid.nix
├── configurations/
│   └── nixos.nix
├── modules/nixos/features/
│   ├── storage/
│   └── impermanence/
└── tests/
    ├── fixtures/hosts/
    ├── installer/
    └── nixos/
~~~

The installer implementation is deliberately split into disk selection, transaction orchestration, and ISO packaging so each can be tested without destructive I/O.

---

### Task 1: Extend the Host Model with Bootstrap and Hardware State

**Files:**
- Modify: nix/lib/hosts.nix
- Create: nix/tests/fixtures/hosts/bootstrap-only/meta.nix
- Create: nix/tests/fixtures/hosts/legacy/meta.nix
- Create: nix/tests/fixtures/hosts/legacy/hardware-configuration.nix
- Create: nix/tests/fixtures/hosts/facter/meta.nix
- Create: nix/tests/fixtures/hosts/facter/facter.json
- Create: nix/tests/lib/hosts-installer.nix
- Modify: nix/checks.nix

**Interfaces:**
- Consumes: existing import of nix/lib/hosts.nix with lib, runtimeContexts, and hostDir.
- Produces each normalized NixOS host with:
  - installer.enable :: bool
  - installer.diskOverride :: null | string
  - hardware.factsPath :: null | path
  - hardware.legacyConfigPath :: null | path
  - hardware.source :: "facter" | "legacy" | "unresolved"
  - hardware.resolved :: bool

- [ ] **Step 1: Add minimal host-registry fixtures**

Each meta.nix contains:

~~~nix
{
  system = "x86_64-linux";
  accounts = {
    primary = "tester";
    users.tester = {
      uid = 1000;
      targets = [ "home" ];
    };
  };
  targets = [ "nixos" ];
  installer = {
    enable = true;
    diskOverride = null;
  };
}
~~~

The legacy fixture hardware file contains an observable marker:

~~~nix
{
  environment.etc."legacy-hardware-marker".text = "legacy\n";
}
~~~

The facter fixture contains:

~~~json
{
  "version": 2,
  "system": "x86_64-linux",
  "virtualisation": "qemu",
  "hardware": {},
  "smbios": {}
}
~~~

- [ ] **Step 2: Write the failing host-model evaluation test**

Assert:

~~~nix
assert bootstrap.hardware.source == "unresolved";
assert !bootstrap.hardware.resolved;
assert bootstrap.hardware.factsPath == null;
assert bootstrap.hardware.legacyConfigPath == null;

assert legacy.hardware.source == "legacy";
assert legacy.hardware.resolved;
assert legacy.hardware.legacyConfigPath != null;

assert facter.hardware.source == "facter";
assert facter.hardware.resolved;
assert facter.hardware.factsPath != null;

assert facter.installer.enable;
assert facter.installer.diskOverride == null;
~~~

Return a runCommandLocal derivation named hosts-installer-eval-test.

- [ ] **Step 3: Run the focused test and confirm failure**

Run:

~~~bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).hosts-installer
~~~

Expected: FAIL because normalized hosts do not yet contain hardware or installer.

- [ ] **Step 4: Normalize installer and hardware state in hosts.nix**

Inside mkHost derive:

~~~nix
factsCandidate = hostDir + "/${host}/facter.json";
legacyCandidate = hostDir + "/${host}/hardware-configuration.nix";
factsPresent = builtins.pathExists factsCandidate;
legacyPresent = builtins.pathExists legacyCandidate;
installerMeta = meta.installer or { };

installer = {
  enable = installerMeta.enable or (systemTargetKind == "nixos");
  diskOverride = installerMeta.diskOverride or null;
};

hardware = {
  factsPath = if factsPresent then factsCandidate else null;
  legacyConfigPath = if legacyPresent then legacyCandidate else null;
  source =
    if factsPresent then "facter"
    else if legacyPresent then "legacy"
    else "unresolved";
  resolved = factsPresent || legacyPresent;
};
~~~

Validate diskOverride:

~~~nix
assert lib.assertMsg (
  installer.diskOverride == null
  || (lib.hasPrefix "/" installer.diskOverride && installer.diskOverride != "/")
) "Host '${host}' installer.diskOverride must be null or an absolute device path";
~~~

- [ ] **Step 5: Wire the check and rerun**

Add to nix/checks.nix:

~~~nix
hosts-installer = import ./tests/lib/hosts-installer.nix {
  inherit lib pkgs;
};
~~~

Expected: PASS.

- [ ] **Step 6: Commit**

~~~bash
git add nix/lib/hosts.nix nix/tests/fixtures/hosts nix/tests/lib/hosts-installer.nix nix/checks.nix
git commit -m "feat: model host bootstrap hardware state"
~~~

---

### Task 2: Make nixos-facter the Preferred Final Hardware Source

**Files:**
- Modify: nix/configurations/common.nix
- Modify: nix/configurations/nixos.nix
- Modify: nix/lib/targets.nix
- Modify: nix/profiles/hosts/aarch64-linux-a/nixos.nix
- Create: nix/tests/nixos/hardware-source.nix
- Modify: nix/checks.nix

**Interfaces:**
- Consumes: config.hardware from Task 1.
- Produces:
  - facter report is preferred whenever present;
  - generated hardware-configuration.nix is migration fallback only;
  - unresolved NixOS hosts are absent from normal nixosConfigurations;
  - bootstrap enumeration remains independent of final-target enumeration.

- [ ] **Step 1: Write the failing hardware-source test**

For a facter-backed system assert:

~~~nix
assert system.config.hardware.facter.reportPath == factsPath;
assert !(system.config.environment.etc ? "legacy-hardware-marker");
~~~

For a legacy system assert:

~~~nix
assert system.config.environment.etc ? "legacy-hardware-marker";
assert system.config.hardware.facter.reportPath == null;
~~~

- [ ] **Step 2: Run the focused test**

Expected: FAIL because hardware source selection is not centralized.

- [ ] **Step 3: Pass hardware and installer through commonSpecialArgs**

Add:

~~~nix
inherit (config)
  hardware
  installer
  ;
~~~

to commonSpecialArgs.

- [ ] **Step 4: Add centralized hardware selection to configurations/nixos.nix**

Add:

~~~nix
hardwareModule =
  config:
  if config.hardware.source == "facter" then
    {
      hardware.facter.reportPath = config.hardware.factsPath;
    }
  else if config.hardware.source == "legacy" then
    {
      imports = [ config.hardware.legacyConfigPath ];
    }
  else
    throw "NixOS host '${config.host}' has no hardware facts";
~~~

Insert hardwareModule config before host profile modules.

Remove the direct hardware-configuration.nix import from aarch64-linux-a/nixos.nix.

- [ ] **Step 5: Filter unresolved final NixOS targets**

In targets.nix introduce:

~~~nix
hostSupportsTarget =
  target: h:
  lib.elem target h.targets
  && (target != "nixos" || h.hardware.resolved);
~~~

Use it for normal target enumeration only.

- [ ] **Step 6: Run focused and full checks**

~~~bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).hardware-source
nix flake check -L
~~~

Expected: PASS. The current host remains evaluable through the legacy fallback until its first facter-based reinstall.

- [ ] **Step 7: Commit**

~~~bash
git add nix/configurations/common.nix nix/configurations/nixos.nix nix/lib/targets.nix nix/profiles/hosts/aarch64-linux-a/nixos.nix nix/tests/nixos/hardware-source.nix nix/checks.nix
git commit -m "feat: prefer facter hardware configuration"
~~~

---

### Task 3: Make Disko the Production Storage Owner

**Files:**
- Create: nix/lib/stable-uuid.nix
- Modify: nix/configurations/nixos.nix
- Modify: nix/flake/default.nix
- Modify: nix/modules/nixos/features/storage/default.nix
- Modify: nix/modules/nixos/features/storage/provisioning.nix
- Modify: nix/tests/nixos/storage-provisioning.nix
- Modify: nix/tests/nixos/storage-provisioning-vm.nix
- Modify: nix/tests/nixos/impermanence-vm.nix

**Interfaces:**
- Produces:
  - production NixOS systems have the Disko provisioning module available;
  - storage.filesystemUuid defaults deterministically from host identity;
  - storage.provisioning.disk defaults to /dev/dotfiles-install-target;
  - physical disk choice is deferred to installer runtime.

- [ ] **Step 1: Add the deterministic UUID helper**

Create nix/lib/stable-uuid.nix:

~~~nix
name:
let
  hex = builtins.substring 0 32 (
    builtins.hashString "sha256" "dotfiles-btrfs:${name}"
  );
in
"${builtins.substring 0 8 hex}-${builtins.substring 8 4 hex}-${builtins.substring 12 4 hex}-${builtins.substring 16 4 hex}-${builtins.substring 20 12 hex}"
~~~

- [ ] **Step 2: Change the storage eval test first**

Stop supplying provisioning.disk in one test case and assert:

~~~nix
assert disk.device == "/dev/dotfiles-install-target";
assert system.config.dotfiles.features.storage.device ==
  "/dev/disk/by-uuid/${system.config.dotfiles.features.storage.filesystemUuid}";
~~~

Expected: FAIL before implementation.

- [ ] **Step 3: Give storage a deterministic UUID default from the host profile**

In configurations/nixos.nix import stable-uuid.nix and set:

~~~nix
dotfiles.features.storage.filesystemUuid =
  lib.mkDefault (stableUuid config.host);
~~~

Keep the option overrideable in isolated tests.

- [ ] **Step 4: Default provisioning.disk to the logical install device**

Change the option to:

~~~nix
disk = lib.mkOption {
  type = lib.types.str;
  default = "/dev/dotfiles-install-target";
  description = "Logical whole-disk path used by destructive Disko provisioning";
};
~~~

- [ ] **Step 5: Import Disko in production NixOS construction**

Add disko to the arguments of configurations/nixos.nix and add:

~~~nix
(import ../modules/nixos/features/storage/provisioning.nix { inherit disko; })
~~~

to modulesFor.

Pass inputs.disko from nix/flake/default.nix.

- [ ] **Step 6: Update VM fixtures**

Where a test exercises the default logical disk, create:

~~~bash
ln -s /dev/vda /dev/dotfiles-install-target
~~~

before diskoScript.

Tests that specifically exercise an arbitrary explicit disk may continue overriding provisioning.disk.

- [ ] **Step 7: Run storage/impermanence checks**

~~~bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).storage-provisioning
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).storage-provisioning-vm
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).impermanence-vm
~~~

Expected: PASS.

- [ ] **Step 8: Commit**

~~~bash
git add nix/lib/stable-uuid.nix nix/configurations/nixos.nix nix/flake/default.nix nix/modules/nixos/features/storage nix/tests/nixos
git commit -m "feat: make disko own production storage"
~~~

---

### Task 4: Implement Fail-Closed Target-Disk Selection

**Files:**
- Create: nix/installer/disk-selector.nu
- Create: nix/tests/installer/disk-selector.nix
- Create: nix/tests/installer/fixtures/one-disk.json
- Create: nix/tests/installer/fixtures/no-disk.json
- Create: nix/tests/installer/fixtures/two-disks.json
- Modify: nix/checks.nix

**Interfaces:**
- Produces: select-install-disk lsblk_json disk_override installer_parent -> string.
- Automatic eligibility: whole disk, rm=false, hotplug=false, not the installer backing disk.
- Override must still name a whole disk and cannot name the installer backing disk.

- [ ] **Step 1: Create lsblk JSON fixtures**

One-disk fixture:

~~~json
{
  "blockdevices": [
    { "path": "/dev/vda", "type": "disk", "rm": false, "hotplug": false },
    { "path": "/dev/sr0", "type": "rom", "rm": true, "hotplug": true }
  ]
}
~~~

Two-disk fixture includes /dev/vda and /dev/vdb as eligible disks. No-disk contains only removable/hotplug media.

- [ ] **Step 2: Write the failing selector test**

~~~nu
assert equal (select-install-disk $one null null) "/dev/vda"
assert error { select-install-disk $none null null }
assert error { select-install-disk $two null null }
assert equal (select-install-disk $two "/dev/vdb" null) "/dev/vdb"
assert error { select-install-disk $two "/dev/vda" "/dev/vda" }
~~~

- [ ] **Step 3: Run the selector check**

Expected: FAIL because disk-selector.nu is absent.

- [ ] **Step 4: Implement the filter**

Core automatic selection:

~~~nu
let candidates = (
  $lsblk.blockdevices
  | where type == "disk"
  | where rm == false
  | where hotplug == false
  | where {|disk| $installer_parent == null or $disk.path != $installer_parent }
)
~~~

Return only if exactly one candidate exists. Include all candidate paths in ambiguity errors.

- [ ] **Step 5: Rerun the selector check**

Expected: PASS.

- [ ] **Step 6: Commit**

~~~bash
git add nix/installer/disk-selector.nu nix/tests/installer nix/checks.nix
git commit -m "feat: add fail-closed installer disk selection"
~~~

---

### Task 5: Implement the Bootstrap Transaction with Destruction Last

**Files:**
- Create: nix/installer/install.nu
- Create: nix/installer/script.nix
- Create: nix/tests/installer/operation.nix
- Modify: nix/checks.nix

**Interfaces:**
- script.nix packages install.nu with:
  - host
  - targetName
  - primaryAccount
  - primaryUid
  - diskOverride
  - concrete command paths
- Embedded Git bundle runtime path: /iso/dotfiles.bundle.
- /dev/dotfiles-install-target is created only after all non-destructive preflight succeeds.

- [ ] **Step 1: Write operation tests using fake commands**

Cover:
1. target build/evaluation failure;
2. ambiguous disk selection;
3. complete successful bootstrap.

Failure assertions:

~~~bash
test ! -e "$TEST_STATE/disko-called"
test ! -e "$TEST_STATE/nixos-install-called"
~~~

Success assertions:

~~~bash
test -e "$TEST_STATE/disko-called"
test -e "$TEST_STATE/nixos-install-called"
git -C "$installed_repo" log -1 --format=%s   | grep -Fx 'bootstrap: record installer state'
~~~

Also assert that the commit changes facter.json and flake.lock.

- [ ] **Step 2: Run and confirm failure**

Expected: FAIL because transaction orchestration is absent.

- [ ] **Step 3: Package command paths in script.nix**

Real defaults must include Git, Nix, nixos-facter, nixos-install, lsblk, findmnt, readlink, ln, cp, mkdir, chown, sync, and Nushell. Tests may override the command attrset with fake binaries.

- [ ] **Step 4: Implement non-destructive preflight**

Order:

~~~text
clone /iso/dotfiles.bundle
→ configure local Git author as "dotfiles installer" <installer@localhost.invalid>
→ regenerate host facter.json
→ git add facter.json
→ nix flake update
→ git add flake.lock
→ build final system toplevel
→ build final system diskoScript
→ commit facter.json + flake.lock
→ inspect lsblk
→ resolve one target disk
~~~

Build paths before disk selection/destruction:

~~~nu
let toplevel = (
  ^$NIX build --no-link --print-out-paths
    $"path:($repo)#nixosConfigurations.($TARGET).config.system.build.toplevel"
  | str trim
)

let disko_script = (
  ^$NIX build --no-link --print-out-paths
    $"path:($repo)#nixosConfigurations.($TARGET).config.system.build.diskoScript"
  | str trim
)
~~~

- [ ] **Step 5: Exclude the live installer disk and canonicalize overrides**

Read /iso's source with findmnt. If it is a partition, use lsblk to resolve its whole-disk parent. If /iso is not backed by a block device, use null; removable/hotplug filtering still applies.

When diskOverride is non-null, resolve it with readlink -f before validating it against lsblk. Reject an override that does not resolve to TYPE=disk or resolves to the installer backing disk.

- [ ] **Step 6: Implement destructive tail**

Only after successful preflight:

~~~text
ln -sfn <selected> /dev/dotfiles-install-target
→ run diskoScript
→ nixos-install --root /mnt --system <toplevel> --no-channel-copy --no-root-password
→ copy Git checkout to /mnt/persist/home/<primary>/dotfiles
→ chown checkout to <primaryUid>
→ sync
~~~

Do not recover or merge data from the previous target filesystem.

- [ ] **Step 7: Rerun operation tests**

Expected: all cases pass and destructive markers remain absent for preflight/selection failures.

- [ ] **Step 8: Commit**

~~~bash
git add nix/installer/install.nu nix/installer/script.nix nix/tests/installer/operation.nix nix/checks.nix
git commit -m "feat: add unattended bootstrap transaction"
~~~

---

### Task 6: Add a Host-Specific Installer ISO Constructor

**Files:**
- Create: nix/installer/iso.nix
- Create: nix/installer/default.nix
- Create: nix/installer/build.nix
- Create: nix/flake/installers.nix
- Modify: nix/flake/default.nix
- Create: nix/tests/installer/iso-eval.nix
- Modify: nix/checks.nix

**Interfaces:**
- Produces: self.lib.mkInstallerIso { host; repositoryBundle; } -> ISO derivation.
- Installer target uses the host's default theme/session and the existing target-name schema.
- ISO construction does not require facter.json.

- [ ] **Step 1: Write a failing ISO evaluation check**

Call mkInstallerIso for a bootstrap-only host and assert the result reaches config.system.build.isoImage without evaluating an unresolved final nixosConfigurations target.

- [ ] **Step 2: Derive the default install target**

Use:
- host.runtime.defaultTheme
- host.runtime.defaultSession
- targetNames.mkSystemTargetName

Do not create a separate installer naming convention for NixOS targets.

- [ ] **Step 3: Implement iso.nix**

Use the minimal installer module:

~~~nix
(nixpkgs.lib.nixosSystem {
  inherit (hostConfig) system;
  modules = [
    (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
    ({ pkgs, ... }: {
      isoImage.contents = [
        {
          source = repositoryBundle;
          target = "dotfiles.bundle";
        }
      ];

      environment.systemPackages = with pkgs; [
        git
        nix
        nixos-facter
        nushell
        util-linux
      ];

      systemd.services.dotfiles-installer = {
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = installerScript;
          ExecStartPost = "${pkgs.systemd}/bin/systemctl reboot";
        };
      };
    })
  ];
}).config.system.build.isoImage
~~~

ExecStartPost runs only after a successful installer command, so failed installs remain in the live installer environment for diagnosis.

- [ ] **Step 4: Export mkInstallerIso through a flake lib output**

Add nix/flake/installers.nix and import it from nix/flake/default.nix. Close the function over the existing host registry, target naming helper, nixpkgs input, and installer script constructor.

Do not expose static installer packages that pretend to contain Git history.

- [ ] **Step 5: Add build.nix as an impure bridge**

~~~nix
{
  repository,
  host,
  repositoryBundle,
}:
let
  flake = builtins.getFlake "path:${repository}";
in
flake.lib.mkInstallerIso {
  inherit host;
  repositoryBundle = builtins.path {
    path = repositoryBundle;
    name = "dotfiles.bundle";
  };
}
~~~

- [ ] **Step 6: Run ISO evaluation and flake checks**

Expected: bootstrap-only ISO evaluates without hardware facts; ordinary final target behavior is unchanged.

- [ ] **Step 7: Commit**

~~~bash
git add nix/installer/iso.nix nix/installer/default.nix nix/installer/build.nix nix/flake/installers.nix nix/flake/default.nix nix/tests/installer/iso-eval.nix nix/checks.nix
git commit -m "feat: add host-specific installer iso constructor"
~~~

---

### Task 7: Add the Clean-Tree build-installer Entry Point

**Files:**
- Create: nix/apps/build-installer/default.nix
- Create: nix/apps/build-installer/script.nix
- Create: nix/apps/build-installer/build.nu
- Create: nix/apps/build-installer/tests/default.nix
- Create: nix/apps/build-installer/tests/run.sh
- Modify: nix/flake/apps.nix
- Modify: nix/checks.nix

**Interfaces:**
- Command: nix run .#build-installer -- --host <host>
- Output link: result-installer-<host>
- Refuses dirty tracked, staged, or untracked state.
- Embeds a verified Git bundle containing the exact HEAD and reachable history.

- [ ] **Step 1: Write wrapper tests**

Test:
1. clean repository succeeds through a fake nix build;
2. modified tracked file fails;
3. staged modification fails;
4. untracked file fails;
5. git bundle verify succeeds;
6. bundle contains git rev-parse HEAD.

- [ ] **Step 2: Run and confirm failure**

Expected: build-installer app is absent.

- [ ] **Step 3: Implement clean-tree enforcement**

Reject any output from:

~~~bash
git status --porcelain=v1 --untracked-files=all
~~~

Record:

~~~bash
git rev-parse HEAD
~~~

for logging and verification.

- [ ] **Step 4: Create the bundle**

~~~bash
git bundle create "$tmp/dotfiles.bundle" HEAD
git bundle verify "$tmp/dotfiles.bundle"
~~~

- [ ] **Step 5: Invoke dynamic ISO build**

~~~bash
nix build --impure   --file "$repository/nix/installer/build.nix"   --argstr repository "$repository"   --argstr host "$host"   --argstr repositoryBundle "$tmp/dotfiles.bundle"   --out-link "$repository/result-installer-$host"
~~~

Do not update flake inputs while building the ISO.

- [ ] **Step 6: Wire app and tests**

Expose apps.build-installer beside update and fix.

Expected: wrapper tests PASS.

- [ ] **Step 7: Commit**

~~~bash
git add nix/apps/build-installer nix/flake/apps.nix nix/checks.nix
git commit -m "feat: add reproducible installer build entry point"
~~~

---

### Task 8: Prove .#update Accepts Local-Only Commits

**Files:**
- Modify: nix/apps/update/tests/run.sh
- Modify only if demonstrated necessary: nix/apps/update/operation.nu

**Interfaces:**
- No new public interface.
- Required behavior: update works when local HEAD is ahead of origin.

- [ ] **Step 1: Add regression test**

Create a bare remote, push a baseline, make one additional local commit without pushing, then run the update fixture.

Assert:

~~~bash
test "$(git -C "$repo" rev-list --count origin/main..HEAD)" -ge 1
test "$(cat "$repo/flake.lock")" = LA
~~~

- [ ] **Step 2: Run update check**

~~~bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).update-operation-consistency
~~~

If it already passes, make no production update-code change.

- [ ] **Step 3: Commit**

~~~bash
git add nix/apps/update/tests/run.sh
git commit -m "test: allow updates from local-only commits"
~~~

If production code required a demonstrated fix, include only that minimal change in the same commit.

---

### Task 9: Add Real-Profile and Installer Lifecycle Integration Tests

**Files:**
- Create: nix/tests/nixos/production-host-impermanence.nix
- Create: nix/tests/installer/e2e-vm.nix
- Modify: nix/checks.nix
- Modify only when required for constructor wiring: nix/flake/checks.nix

**Interfaces:**
- Production check consumes real self.nixosConfigurations.
- VM test follows the existing NixOS installer pattern: installer writes an empty disk, shuts down, target reuses installer.state_dir, target boots the installed disk.

- [ ] **Step 1: Add production-host assertions**

For every resolved facter-backed host with impermanence enabled, assert:

~~~nix
assert config.dotfiles.features.impermanence.enable;
assert config.dotfiles.features.storage.provisioning.enable;
assert config.disko.enableConfig;
assert config.fileSystems."/".fsType == "btrfs";
assert config.fileSystems."/nix".fsType == "btrfs";
assert config.fileSystems."/persist".fsType == "btrfs";
assert config.hardware.facter.reportPath != null;
~~~

Before the real host has completed first bootstrap, skip its legacy state instead of claiming it is migrated.

- [ ] **Step 2: Build an installer lifecycle VM**

Use actual production modules for:
- storage provisioning;
- impermanence;
- preservation;
- test instrumentation.

Use one normal user and a deterministic local Git bundle. Replace only hardware probing with a fake facter binary that writes a valid VM report; keep real Disko and nixos-install.

- [ ] **Step 3: Reuse installer disk state for target boot**

Test driver:

~~~python
installer.shutdown()
target.state_dir = installer.state_dir
target.start()
target.wait_for_unit("multi-user.target")
~~~

- [ ] **Step 4: Verify mount topology**

~~~bash
test "$(findmnt -n -o FSTYPE /)" = btrfs
test "$(findmnt -n -o FSROOT /)" = /@root
test "$(findmnt -n -o FSROOT /nix)" = /@nix
test "$(findmnt -n -o FSROOT /persist)" = /@persist
~~~

Create disposable and persistent markers, reboot, then prove only the persistent marker survives.

- [ ] **Step 5: Verify repository persistence**

~~~bash
test -d /home/tester/dotfiles/.git
git -C /home/tester/dotfiles log -1 --format=%s   | grep -Fx 'bootstrap: record installer state'
~~~

- [ ] **Step 6: Add ambiguous-disk negative integration case**

Give the installer two eligible non-removable disks and no override. Assert:
- /dev/dotfiles-install-target is never created;
- neither disk receives the configured GPT partition label.

- [ ] **Step 7: Run focused checks**

~~~bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).installer-e2e-vm
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).production-host-impermanence
~~~

Platform gating must follow the repository's existing Linux/KVM policy and must not add a new unconditional KVM requirement.

- [ ] **Step 8: Commit**

~~~bash
git add nix/tests/installer/e2e-vm.nix nix/tests/nixos/production-host-impermanence.nix nix/checks.nix nix/flake/checks.nix
git commit -m "test: cover installer and production impermanence path"
~~~

---

### Task 10: Enable the Real Host's Post-Bootstrap Impermanence Policy

**Files:**
- Modify: nix/profiles/hosts/aarch64-linux-a/meta.nix
- Modify: nix/profiles/hosts/aarch64-linux-a/nixos.nix
- Keep during migration: nix/profiles/hosts/aarch64-linux-a/hardware-configuration.nix
- Generated by installer after rollout: nix/profiles/hosts/aarch64-linux-a/facter.json
- Modify: README.org
- Modify: flake.nix comments

**Interfaces:**
- Pre-bootstrap: current legacy host remains evaluable and does not suddenly reinterpret ext4 as Btrfs.
- Post-bootstrap: presence of facter.json selects facter hardware and enables Disko + preservation + impermanence.

- [ ] **Step 1: Add explicit installer metadata**

~~~nix
installer = {
  enable = true;
  diskOverride = null;
};
~~~

- [ ] **Step 2: Gate migration-sensitive features on facter**

Update the host module:

~~~nix
{ lib, hardware, ... }:
{
  dotfiles = {
    nixos.boot.performanceTuning.enable = lib.mkDefault true;

    features = lib.mkIf (hardware.source == "facter") {
      storage.provisioning.enable = true;
      preservation.enable = true;
      impermanence.enable = true;
    };
  };
}
~~~

This guard prevents an ordinary update on the current ext4 installation from activating Btrfs semantics before the destructive installer has run.

- [ ] **Step 3: Verify current pre-bootstrap host still evaluates**

Run the current aarch64 NixOS target evaluation/build check before any facter.json exists.

Expected: PASS through the legacy hardware fallback.

- [ ] **Step 4: Update lifecycle documentation**

Document:

~~~text
Create or recreate a machine:
  nix run .#build-installer -- --host <host>
  boot the resulting host ISO

Maintain an installed machine:
  nix run .#update
~~~

State explicitly that booting the installer ISO wipes the selected disk completely.

Replace the old preferred new-host workflow that copies generated hardware-configuration.nix. Document legacy hardware files only as migration compatibility before a host's first facter-based reinstall.

- [ ] **Step 5: Commit**

~~~bash
git add nix/profiles/hosts/aarch64-linux-a/meta.nix nix/profiles/hosts/aarch64-linux-a/nixos.nix README.org flake.nix
git commit -m "feat: enable facter-backed impermanence bootstrap"
~~~

---

### Task 11: Final Verification and Installer Build

**Files:**
- No planned production edits; change code only for failures demonstrated by these checks.

**Interfaces:**
- Verifies the approved spec before any destructive real-machine rollout.

- [ ] **Step 1: Format and lint**

~~~bash
nix run .#fix
git diff --check
~~~

Expected: no formatting or whitespace failures.

- [ ] **Step 2: Run full checks**

~~~bash
nix flake check -L
~~~

Expected: every check applicable to the current platform passes.

- [ ] **Step 3: Run update regression directly**

~~~bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).update-operation-consistency
~~~

Expected: PASS including local-ahead-of-remote state.

- [ ] **Step 4: Verify dirty-tree rejection**

~~~bash
touch .installer-dirty-probe
if nix run .#build-installer -- --host aarch64-linux-a; then
  echo "installer build unexpectedly accepted dirty tree" >&2
  rm .installer-dirty-probe
  exit 1
fi
rm .installer-dirty-probe
~~~

Expected: builder refuses before ISO construction.

- [ ] **Step 5: Build the clean host installer**

~~~bash
nix run .#build-installer -- --host aarch64-linux-a
~~~

Expected: result-installer-aarch64-linux-a points to the built ISO output.

- [ ] **Step 6: Verify repository state**

~~~bash
git status --short
git log --oneline --decorate -12
~~~

Expected:
- clean working tree;
- focused task commits;
- no fabricated facter.json on the development machine.

- [ ] **Step 7: Stop at the destructive rollout boundary**

Implementation completion does not include booting the ISO on the real machine.

The subsequent operational action is:

~~~text
write the host ISO to boot media
→ boot target
→ unattended installer regenerates facter.json
→ installer updates flake.lock and commits both locally
→ fail-closed disk selector chooses the target
→ Disko wipes and provisions
→ NixOS installs
→ local Git checkout persists under /persist
~~~

There is intentionally no interactive confirmation prompt.

- [ ] **Step 8: Commit verification-only fixes only when required**

If verification exposes a concrete defect, commit only that demonstrated correction. If no corrections are required, create no empty commit.
