# NixOS Impermanence Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a host-specific NixOS installer that installs the host's declared default runtime configuration from the current pushed `main`, records fresh hardware facts, provisions the Disko Btrfs impermanence layout on the sole eligible internal disk, installs a persistent administrator password, and powers off for manual installer-media removal.

**Architecture:** The repository declares one canonical anonymous HTTPS origin and derives one installer target per host from `runtime.defaultTheme` and `runtime.defaultSession`. The ISO embeds only host, origin, and clean Git commit metadata. At runtime it clones that exact still-current `origin/main`, generates `facter.json`, evaluates the final host with frozen lock semantics, requires exactly one eligible internal disk twice, provisions through Disko, installs into the target `/nix` store, verifies the fallback EFI loader, persists the Git checkout, and powers off.

**Tech Stack:** NixOS/nixpkgs, flake-parts, Disko, nixos-facter, preservation, Nushell, Git, systemd-boot, UEFI fallback boot, NixOS VM tests.

**Spec:** `docs/superpowers/specs/2026-09-18-nixos-impermanence-bootstrap-design.md`

## Global Constraints

- Canonical repository origin is declared once in Nix as `https://github.com/sugiura-hiromiti/dotfiles.git`.
- `build-installer` accepts only a clean local `main` whose exact `origin` matches the declared URL and whose `HEAD == origin/main`.
- Anonymous access is verified without interactive prompts or credential helpers.
- Installer target selection is always the host's declared `runtime.defaultTheme` + `runtime.defaultSession`; there are no installer theme/session flags.
- The ISO records only host, declared origin, and exact clean commit.
- Installation requires network access and aborts if remote `origin/main` no longer equals the embedded commit.
- Installer Nix operations use both `--no-update-lock-file` and `--no-write-lock-file`.
- Installation never runs `nix flake update`.
- The bootstrap ISO can build without `facter.json`; the final target evaluates only after fresh facts are generated.
- Disko is the sole owner of installed GPT/ESP/Btrfs topology.
- The installed Btrfs partition is addressed by a host-specific GPT partition label, not a filesystem UUID.
- There is no target-disk override. Exactly one internal, non-removable, non-hotplug whole disk is required at preflight and again immediately before Disko.
- Supported installer media must not qualify as that target.
- Simultaneously attached clones of one host are unsupported; duplicate partition-label resolution fails closed during initrd.
- The primary administrator password hash lives under `/persist`, outside Git and the Nix store.
- `boot.loader.efi.canTouchEfiVariables = false`; boot relies on the standard `EFI/BOOT/BOOT<ARCH>.EFI` fallback loader.
- There is no custom `BootOrder`, `BootNext`, firmware-entry creation, kexec, completion marker, or re-entry protocol.
- Successful installation ends with sync, recursive unmount, and poweroff.
- `.#update` remains the normal dependency-update path.
- Migration-only `hardware-configuration.nix` support must stay isolated from the final architecture.
- The implementation stops after building and verifying the real installer ISO; it does not boot it on the real machine.

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
│   │   ├── script.nix
│   │   ├── build.nu
│   │   └── tests/run.sh
│   └── test-installer-e2e/
│       └── default.nix
├── modules/nixos/features/
│   ├── bootstrap-credentials.nix
│   ├── storage/
│   │   ├── default.nix
│   │   └── provisioning.nix
│   └── impermanence/
│       └── ephemeral-root.nix
├── tests/
│   ├── installer/
│   │   ├── runtime.nix
│   │   └── e2e.nix
│   └── nixos/
│       ├── bootstrap-credentials.nix
│       ├── storage-provisioning.nix
│       ├── storage-provisioning-vm.nix
│       ├── ephemeral-root.nix
│       └── impermanence-vm.nix
├── configurations/nixos.nix
├── lib/runtime.nix
├── lib/targets.nix
├── flake/apps.nix
├── flake/default.nix
└── checks.nix
```

The installer stays deliberately small: one live transaction script, one ISO constructor, and one build wrapper. Do not recreate handoff, re-entry, stable-disk-ID, Git-bundle, or deterministic-filesystem-UUID subsystems.

---

### Task 1: Declare Installer Identity and Resolve One Default Runtime Target

**Files:**
- Create: `nix/installer/config.nix`
- Modify: `nix/lib/runtime.nix`
- Modify: `nix/lib/targets.nix`
- Modify: `nix/flake/default.nix`
- Create: `nix/tests/lib/installer-target.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- `installerConfig.origin :: string`
- `runtime.mkRuntimeContext :: themeName -> sessionName -> runtimeContext`
- `targets.mkDefaultHostTargetConfig :: hostName -> systemTargetConfig`
- Flake output: `installer.origin`, `installer.hosts.<host>.target`, `installer.hosts.<host>.primaryAccount`, `installer.hosts.<host>.system`.

- [ ] **Step 1: Write the failing target-resolution test**

Create `nix/tests/lib/installer-target.nix` with assertions equivalent to:

```nix
let
  config = mkDefaultHostTargetConfig "aarch64-linux-a";
in
assert config.themeName == hosts.aarch64-linux-a.runtime.defaultTheme;
assert config.sessionName == hosts.aarch64-linux-a.runtime.defaultSession;
assert config.configName ==
  targetNames.mkSystemTargetName {
    inherit (config) targetHost themeName sessionName;
    inherit (config.runtime) targetAxes;
  };
pkgs.writeText "installer-target" "ok\n"
```

Also assert the declared origin is exactly `https://github.com/sugiura-hiromiti/dotfiles.git`.

- [ ] **Step 2: Run the focused check and observe failure**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).installer-target
```

Expected: FAIL because the interface does not exist yet.

- [ ] **Step 3: Add repository-wide installer configuration**

Create `nix/installer/config.nix`:

```nix
{
  origin = "https://github.com/sugiura-hiromiti/dotfiles.git";
}
```

Do not put this URL in host metadata.

- [ ] **Step 4: Expose one runtime-context constructor**

Export the existing internal `mkRuntimeContext` from `nix/lib/runtime.nix`; do not duplicate context resolution.

- [ ] **Step 5: Add default-target resolution**

In `nix/lib/targets.nix` add:

```nix
mkDefaultHostTargetConfig =
  hostName:
  let
    host = hosts.${hostName};
    runtimeContext = runtime.mkRuntimeContext
      host.runtime.defaultTheme
      host.runtime.defaultSession;
  in
  mkHostTargetConfig (applyRuntimeContext host runtimeContext);
```

Export it.

- [ ] **Step 6: Publish pure installer metadata**

In `nix/flake/default.nix`, import `../installer/config.nix` once and expose:

```nix
flake.installer = {
  inherit (installerConfig) origin;
  hosts = lib.genAttrs hostNames (
    hostName:
    let
      target = targets.mkDefaultHostTargetConfig hostName;
    in
    {
      target = target.configName;
      primaryAccount = target.primaryAccountName;
      system = target.system;
    }
  );
};
```

This output must not evaluate a final NixOS system, so it works before `facter.json` exists.

- [ ] **Step 7: Rerun focused and full checks**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).installer-target
nix flake check -L
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add nix/installer/config.nix nix/lib/runtime.nix nix/lib/targets.nix nix/flake/default.nix nix/tests/lib/installer-target.nix nix/checks.nix
git commit -m "feat: define deterministic installer target"
```

---

### Task 2: Make Facter the Final Hardware Source While Preserving Only the Current Migration Path

**Files:**
- Modify: `nix/configurations/nixos.nix`
- Modify: `nix/profiles/hosts/aarch64-linux-a/nixos.nix`
- Create: `nix/tests/nixos/hardware-source.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- Final host with `facter.json`: `hardware.facter.reportPath = <host>/facter.json`.
- Current host without `facter.json`: temporary import of its existing `hardware-configuration.nix`.
- No new host-registry hardware-state abstraction.

- [ ] **Step 1: Write the focused hardware-source test**

Cover a facter-backed fixture and a migration fixture. Assert:

```nix
assert facterSystem.config.hardware.facter.reportPath == facterPath;
assert !(facterSystem.config.environment.etc ? "legacy-hardware-marker");

assert legacySystem.config.environment.etc ? "legacy-hardware-marker";
assert legacySystem.config.hardware.facter.reportPath == null;
```

The migration fixture's legacy module contains:

```nix
{ environment.etc."legacy-hardware-marker".text = "legacy\n"; }
```

- [ ] **Step 2: Verify the focused test fails**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).hardware-source
```

- [ ] **Step 3: Centralize hardware selection in the NixOS constructor**

In `nix/configurations/nixos.nix` derive:

```nix
hostDir = ../profiles/hosts + "/${config.host}";
facterPath = hostDir + "/facter.json";
legacyPath = hostDir + "/hardware-configuration.nix";
hasFacter = builtins.pathExists facterPath;
```

Append exactly one hardware module:

```nix
if hasFacter then
  { hardware.facter.reportPath = facterPath; }
else if builtins.pathExists legacyPath then
  legacyPath
else
  throw "NixOS host '${config.host}' has neither facter.json nor migration hardware configuration"
```

Do not add `hardware.source` or similar state to `nix/lib/hosts.nix`.

- [ ] **Step 4: Remove the host-local legacy import**

Delete `imports = [ ./hardware-configuration.nix ];` from `nix/profiles/hosts/aarch64-linux-a/nixos.nix`. Keep the file itself for migration.

- [ ] **Step 5: Verify both paths and commit**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).hardware-source
nix flake check -L

git add nix/configurations/nixos.nix nix/profiles/hosts/aarch64-linux-a/nixos.nix nix/tests/nixos/hardware-source.nix nix/checks.nix
git commit -m "feat: centralize facter hardware selection"
```

---

### Task 3: Replace Filesystem UUID Identity With the Host Partition Label and Wire Production Disko/Impermanence

**Files:**
- Modify: `nix/configurations/nixos.nix`
- Modify: `nix/flake/default.nix`
- Modify: `nix/modules/nixos/features/storage/default.nix`
- Modify: `nix/modules/nixos/features/storage/provisioning.nix`
- Modify: `nix/modules/nixos/features/impermanence/impermanence.nix`
- Modify: `nix/modules/nixos/features/impermanence/ephemeral-root.nix`
- Modify: `nix/tests/nixos/storage-provisioning.nix`
- Modify: `nix/tests/nixos/storage-provisioning-vm.nix`
- Modify: `nix/tests/nixos/ephemeral-root.nix`
- Modify: `nix/tests/nixos/impermanence-vm.nix`

**Interfaces:**
- `dotfiles.features.storage.partitionLabel :: string`
- `dotfiles.features.storage.device = "/dev/disk/by-partlabel/${partitionLabel}"`
- `dotfiles.features.storage.provisioning.disk` defaults to `/dev/dotfiles-install-target`.
- Resolved host label: `dotfiles-<host>`.
- Initrd requires exactly one partition matching the PARTLABEL before mounting/deleting `@root`.

- [ ] **Step 1: Change the storage evaluation test first**

Remove the UUID fixture and assert:

```nix
assert systemPartition.label == "test-system";
assert systemPartition.device == "/dev/disk/by-partlabel/test-system";
assert system.config.dotfiles.features.storage.device ==
  "/dev/disk/by-partlabel/test-system";
assert disk.device == "/dev/dotfiles-install-target";
```

Run the check and expect failure while UUID identity remains.

- [ ] **Step 2: Simplify the storage module**

Remove `filesystemUuid`. Define `partitionLabel` in `storage/default.nix` and make `device` read-only with:

```nix
default = "/dev/disk/by-partlabel/${cfg.partitionLabel}";
```

- [ ] **Step 3: Simplify Disko provisioning**

Keep `label = storage.partitionLabel`, remove Btrfs `extraArgs = [ "-U" ... ]`, and set:

```nix
provisioning.disk = lib.mkOption {
  type = lib.types.str;
  default = "/dev/dotfiles-install-target";
};
```

- [ ] **Step 4: Wire the final storage policy only after facter exists**

Pass `disko` into `nix/configurations/nixos.nix`. When `hasFacter` is true, import provisioning and set:

```nix
dotfiles.features.storage = {
  partitionLabel = "dotfiles-${config.host}";
  provisioning.enable = true;
};
dotfiles.features.preservation.enable = true;
dotfiles.features.impermanence.enable = true;
```

Assert the GPT label length is at most 36 characters. While `facter.json` is absent, keep the current ext4 migration system unchanged.

- [ ] **Step 5: Add explicit initrd label validation**

Add `dotfiles.features.ephemeralRoot.partitionLabel :: string`. Have `impermanence.nix` pass `storage.partitionLabel` into it.

Before the Btrfs mount, run `${pkgs.util-linux}/bin/blkid -t PARTLABEL=<label> -o device`, normalize unique non-empty device lines, and require exactly one. Zero or multiple matches exit non-zero.

Make the Btrfs mount require and run after this validation service; root deletion must therefore never run on an ambiguous label.

- [ ] **Step 6: Update existing VM mappings without inventing global disk names**

Keep:

```text
storage-provisioning-vm: target /dev/vdb
impermanence-vm:          target /dev/vda
```

Each fixture creates `/dev/dotfiles-install-target` pointing to its already-established blank target before Disko.

- [ ] **Step 7: Add duplicate-label failure coverage**

Attach a second partition with `PARTLABEL=test-system`. Starting the ephemeral-root boot path must fail before the delete service runs.

- [ ] **Step 8: Run checks and commit**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).storage-provisioning
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).storage-provisioning-vm
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).ephemeral-root
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).impermanence-vm
git add nix/configurations/nixos.nix nix/flake/default.nix nix/modules/nixos/features/storage nix/modules/nixos/features/impermanence nix/tests/nixos
git commit -m "feat: use partition labels for impermanent storage"
```

---

### Task 4: Declare Persistent Administrator Credentials

**Files:**
- Create: `nix/modules/nixos/features/bootstrap-credentials.nix`
- Modify: `nix/modules/nixos/default.nix`
- Modify: `nix/configurations/nixos.nix`
- Create: `nix/tests/nixos/bootstrap-credentials.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- `dotfiles.features.bootstrapCredentials.enable :: bool`
- `dotfiles.features.bootstrapCredentials.hashFile :: string`
- Default primary-user hash path: `/persist/etc/dotfiles/password-<primary>.hash`.

- [ ] **Step 1: Write the failing credentials test**

For primary user `a`:

```nix
assert system.config.users.mutableUsers == false;
assert system.config.users.users.a.hashedPasswordFile ==
  "/persist/etc/dotfiles/password-a.hash";
assert system.config.dotfiles.features.bootstrapCredentials.hashFile ==
  "/persist/etc/dotfiles/password-a.hash";
```

- [ ] **Step 2: Run and observe failure**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).bootstrap-credentials
```

- [ ] **Step 3: Implement the module**

Using the existing `accounts.primary` special argument:

```nix
config = lib.mkIf cfg.enable {
  users.mutableUsers = false;
  users.users.${accounts.primary}.hashedPasswordFile = cfg.hashFile;
};
```

The hash-file option is a string, not a Nix path.

- [ ] **Step 4: Enable credentials only on the facter-resolved final system**

Under the same `hasFacter` gate from Task 3:

```nix
dotfiles.features.bootstrapCredentials.enable = true;
```

Do not enable it on the migration system before the persistent hash exists.

- [ ] **Step 5: Verify and commit**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).bootstrap-credentials
nix flake check -L
git add nix/modules/nixos/features/bootstrap-credentials.nix nix/modules/nixos/default.nix nix/configurations/nixos.nix nix/tests/nixos/bootstrap-credentials.nix nix/checks.nix
git commit -m "feat: declare persistent bootstrap credentials"
```

---

### Task 5: Implement the Single Installer Transaction

**Files:**
- Create: `nix/installer/install.nu`
- Create: `nix/installer/script.nix`
- Create: `nix/tests/installer/runtime.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- `mkInstallerScript { host; origin; commit; efiArch; } -> package`
- Runtime immutable inputs: host, origin, commit, EFI architecture.
- Runtime checkout: `/run/dotfiles-installer/repo`.
- Temporary target alias: `/dev/dotfiles-install-target`.

- [ ] **Step 1: Add disk-selection tests**

Feed synthetic `lsblk --json --output PATH,TYPE,RM,HOTPLUG` data.

Exactly one eligible disk:

```json
{"blockdevices":[
  {"path":"/dev/sda","type":"disk","rm":false,"hotplug":false},
  {"path":"/dev/sr0","type":"rom","rm":true,"hotplug":true}
]}
```

Expected: `/dev/sda`.

Zero eligible disks and two eligible disks must fail. Do not add override behavior.

- [ ] **Step 2: Add stale-origin and frozen-lock command tests**

With fake `git` and `nix`, prove:

- fetched `origin/main != commit` aborts;
- every installation-flake `nix eval`, `nix build`, and `nixos-install --flake` command contains both frozen-lock flags;
- no installer command runs `nix flake update`.

- [ ] **Step 3: Implement Git verification**

The script runs:

```text
git clone <origin> /run/dotfiles-installer/repo
git -C <repo> fetch origin main
git -C <repo> rev-parse refs/remotes/origin/main
```

Compare that SHA exactly with the embedded commit. On equality:

```bash
git -C "$repo" switch -C main "$commit"
git -C "$repo" branch --set-upstream-to=origin/main main
```

Mismatch exits before password prompting and before destructive work.

- [ ] **Step 4: Capture and hash the password**

Prompt twice with terminal echo suppressed. Reject empty or mismatched input. Pipe plaintext through the Nix-provided `mkpasswd --method=yescrypt --stdin`; never place plaintext in argv or a file. Retain only the hash variable.

- [ ] **Step 5: Generate and conditionally commit facter**

Run:

```text
nixos-facter -o nix/profiles/hosts/<host>/facter.json
git add nix/profiles/hosts/<host>/facter.json
```

If `git diff --cached --quiet` succeeds, do not commit. Otherwise commit only that file with message `bootstrap: record hardware facts` and a fixed installer-local author identity. Never push.

- [ ] **Step 6: Resolve the final Nix target and account values**

Read with frozen-lock flags:

```text
installer.hosts.<host>.target
installer.hosts.<host>.primaryAccount
nixosConfigurations.<target>.config.system.build.toplevel.drvPath
nixosConfigurations.<target>.config.users.users.<primary>.home
nixosConfigurations.<target>.config.users.users.<primary>.uid
nixosConfigurations.<target>.config.users.users.<primary>.group
nixosConfigurations.<target>.config.users.groups.<group>.gid
nixosConfigurations.<target>.config.dotfiles.features.bootstrapCredentials.hashFile
```

Evaluating the toplevel `drvPath` is the full pre-destructive final-configuration evaluation. Reject null or non-integer UID/GID values.

- [ ] **Step 7: Realize only the Disko script before destruction**

Build `nixosConfigurations.<target>.config.system.build.diskoScript` with `--no-link --print-out-paths` plus both frozen-lock flags. Do not realize the final toplevel.

- [ ] **Step 8: Perform the two fail-closed disk scans**

Filter `lsblk` to whole disks where `RM == false/0` and `HOTPLUG == false/0`. Require exactly one at preflight.

Immediately before Disko, repeat the full scan and again require exactly one. Do not preserve or compare a cross-time physical identity.

Only after the second scan:

```bash
ln -sfn "$disk" /dev/dotfiles-install-target
```

- [ ] **Step 9: Provision and install**

Run Disko, then require `/mnt`, `/mnt/boot`, `/mnt/nix`, and `/mnt/persist` to be mountpoints.

Write the hash to `/mnt + <evaluated hashFile>` with parent mode `0700` and file mode `0600`.

Install:

```bash
nixos-install   --root /mnt   --flake "path:$repo#$target"   --no-update-lock-file   --no-write-lock-file   --no-channel-copy   --no-root-password
```

- [ ] **Step 10: Verify fallback EFI installation**

Require `/mnt/boot/EFI/BOOT/BOOT<UPPERCASE_EFI_ARCH>.EFI`. For aarch64 this is `BOOTAA64.EFI`. Do not inspect or write EFI variables.

- [ ] **Step 11: Persist the checkout with evaluated ownership**

Destination is `/mnt/persist + <home> + /dotfiles`. Copy the full checkout including `.git`, recursively chown it to evaluated UID:GID, then verify:

```text
branch = main
origin = declared HTTPS origin
origin/main = embedded commit
local HEAD = embedded commit or one facter commit ahead
```

- [ ] **Step 12: Finish safely**

Run `sync`, recursively unmount `/mnt`, verify it is no longer mounted, then `systemctl poweroff`. Earlier errors exit non-zero and leave the installer running for diagnosis.

- [ ] **Step 13: Run tests and commit**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).installer-runtime
nix flake check -L
git add nix/installer/install.nu nix/installer/script.nix nix/tests/installer/runtime.nix nix/checks.nix
git commit -m "feat: implement deterministic installer transaction"
```

---

### Task 6: Build the Host ISO and Enforce the Builder Git Contract

**Files:**
- Create: `nix/installer/iso.nix`
- Create: `nix/apps/build-installer/default.nix`
- Create: `nix/apps/build-installer/script.nix`
- Create: `nix/apps/build-installer/build.nu`
- Create: `nix/apps/build-installer/tests/run.sh`
- Modify: `nix/flake/apps.nix`
- Modify: `nix/flake/default.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- Package: `packages.installer-<host>` on the host's matching system.
- App: `nix run .#build-installer -- --host <host>`.
- Result link: `result/installer-<host>`.

- [ ] **Step 1: Write builder-contract tests first**

Using temporary Git repositories and a fake `nix`, assert rejection of: non-`main` branch, detached HEAD, tracked changes, staged changes, untracked files, wrong local origin, `HEAD != origin/main`, and anonymous `ls-remote` failure.

Assert success only when every invariant passes and the requested package is exactly `installer-<host>`.

- [ ] **Step 2: Verify anonymous origin without credentials**

Reject non-HTTPS declared origins. Probe with prompting/helpers disabled:

```bash
GIT_TERMINAL_PROMPT=0 git -c credential.helper=   ls-remote "$declared_origin" refs/heads/main
```

A cached credential must not be required.

- [ ] **Step 3: Enforce the local Git invariant**

Require:

```text
git symbolic-ref --quiet --short HEAD == main
git status --porcelain --untracked-files=all == empty
git remote get-url origin == declared origin
git fetch origin main succeeds
git rev-parse HEAD == git rev-parse refs/remotes/origin/main
```

Exact origin equality is intentional; do not normalize or rewrite it.

- [ ] **Step 4: Construct the ISO without evaluating the final host**

`iso.nix` imports nixpkgs' minimal installation-CD module and installs the Task 5 runtime script.

Constructor inputs are exactly:

```nix
{ host, origin, commit }
```

Derive `efiArch` from the ISO platform's `pkgs.stdenv.hostPlatform.efiArch`.

Configure `dotfiles-installer.service` to start after `network-online.target`, use tty1 for stdin/stdout/stderr, run once, remain running on failure, and let the script power off on success.

Do not reference `nixosConfigurations.<target>.config.system.build.toplevel` from ISO construction.

- [ ] **Step 5: Generate one installer package per NixOS host**

Use:

```nix
commit =
  if self ? rev then self.rev
  else throw "installer ISO requires a clean Git flake revision";
```

Expose `packages.installer-<host>` only in the matching `perSystem` system.

- [ ] **Step 6: Implement the build app**

After Git validation:

```text
nix build path:<repository>#installer-<host>
  --out-link <repository>/result/installer-<host>
```

The already-ignored `result/` directory is the only output location.

- [ ] **Step 7: Verify bootstrap independence**

Add checks proving the ISO package can be evaluated/built without `facter.json`, its installer service is enabled, and no Git bundle or repository snapshot is embedded as source state.

- [ ] **Step 8: Run tests and commit**

```bash
nix flake check -L
nix run .#build-installer -- --help
git add nix/installer/iso.nix nix/apps/build-installer nix/flake/apps.nix nix/flake/default.nix nix/checks.nix
git commit -m "feat: build host-specific installer iso"
```

---

### Task 7: Add the Networked Lifecycle E2E and Finish the Migration-Safe Deliverable

**Files:**
- Create: `nix/tests/installer/e2e.nix`
- Create: `nix/apps/test-installer-e2e/default.nix`
- Modify: `nix/flake/apps.nix`
- Modify: `nix/checks.nix`
- Modify: `README.md` or the repository's existing NixOS operations documentation
- Keep temporarily: `nix/profiles/hosts/aarch64-linux-a/hardware-configuration.nix`

**Interfaces:**
- Manual/networked app: `nix run .#test-installer-e2e`.
- Runtime executes a NixOS test driver outside the build sandbox via `<driverInteractive>/bin/nixos-test-driver --no-interactive`.

- [ ] **Step 1: Keep network execution out of `nix flake check`**

It is acceptable for `nix flake check` to evaluate/build the E2E driver closure, but it must not execute the network-dependent test derivation.

The app runs the already-built `driverInteractive` program with `--no-interactive` so the test process itself has normal runtime network access.

- [ ] **Step 2: Model only the supported hardware**

The E2E VM presents UEFI, the installer as CD/ISO media, exactly one writable non-removable target disk, network connectivity, and no second eligible internal disk.

Do not add a generic firmware/disk matrix.

- [ ] **Step 3: Test stale-ISO rejection**

Run the production installer runtime with an intentionally wrong embedded commit. Assert the installer exits before Disko, the target partition table remains unchanged, and the destructive target alias is not used.

- [ ] **Step 4: Run the real successful lifecycle**

Use the declared anonymous HTTPS origin and actual current pushed `main`. The E2E app therefore checks the same clean/pushed-main invariant as `build-installer`.

Feed a deterministic test password through the VM console and verify:

1. clone/fetch;
2. remote-main commit equality;
3. fresh facter generation;
4. conditional facter commit;
5. frozen-lock final evaluation;
6. both single-disk scans;
7. Disko GPT + ESP + Btrfs provisioning;
8. target-store `nixos-install`;
9. fallback `EFI/BOOT/BOOT<ARCH>.EFI`;
10. persistent checkout branch/origin/UID/GID;
11. installer poweroff.

- [ ] **Step 5: Boot the installed disk with installer media removed**

Restart without the installer CD and verify:

```text
/        -> @root
/nix     -> @nix
/persist -> @persist
```

The machine must reach `multi-user.target` through the fallback EFI path.

- [ ] **Step 6: Verify authentication and root reset**

Using the deterministic fixture password, prove local password authentication and `sudo` authentication.

Create a disposable root marker, an existing-policy persistent marker, and a file inside the persisted dotfiles checkout. Reboot and assert the root marker disappeared while persistent state and the checkout survived.

- [ ] **Step 7: Add the lock-mutation regression**

Create a fixture clone whose `flake.nix` requires a lock update while its committed `flake.lock` is unchanged. The installer's pre-destructive evaluation must fail under the two frozen-lock flags.

- [ ] **Step 8: Run deterministic tests**

```bash
nix flake check -L
```

Expected: PASS.

- [ ] **Step 9: Run networked E2E from clean pushed main**

```bash
nix run .#test-installer-e2e
```

Expected: PASS.

If required virtualization/KVM support is unavailable, report that environmental limitation; do not add a TCG fallback merely to make the test pass.

- [ ] **Step 10: Recheck updater separation**

Run the existing update-app tests and inspect `nix/apps/update/operation.nu`. Preserve:

```text
installer: never updates flake.lock
.#update: normal path that runs nix flake update
```

Do not add destructive bootstrap behavior to `.#update`.

- [ ] **Step 11: Document the operator flow**

Document:

```text
1. ensure main is clean and pushed
2. nix run .#build-installer -- --host aarch64-linux-a
3. write/attach result/installer-aarch64-linux-a ISO
4. boot installer
5. enter administrator password
6. wait for poweroff
7. remove/eject installer media
8. power on
```

Also list the unsupported cases from the spec.

- [ ] **Step 12: Build the real installer, but do not boot it**

From clean pushed `main`:

```bash
nix run .#build-installer -- --host aarch64-linux-a
test -e result/installer-aarch64-linux-a
```

Inspect the resulting ISO path and verify its embedded commit is the expected `HEAD`.

**STOP HERE. Do not boot the ISO on the real machine as part of implementation.**

- [ ] **Step 13: Keep the migration fallback until the real migration**

Do not delete `nix/profiles/hosts/aarch64-linux-a/hardware-configuration.nix` before the first real install has generated and retained `facter.json`.

After that real installation, make a separate bounded cleanup change that removes the legacy fallback and proves the production host evaluates only from facter.

- [ ] **Step 14: Commit**

```bash
git add nix/tests/installer/e2e.nix nix/apps/test-installer-e2e nix/flake/apps.nix nix/checks.nix README.md
git commit -m "test: cover full nixos installer lifecycle"
```

---

## Plan Self-Review Checklist

- [ ] No disk override or stable `/dev/disk/by-id` target metadata.
- [ ] No Git bundle.
- [ ] No deterministic Btrfs filesystem UUID.
- [ ] No EFI-variable writes or requirements.
- [ ] No `BootNext`, `BootOrder`, kexec, installer ID, completion marker, or automatic re-entry.
- [ ] ISO construction does not evaluate the final host before facter exists.
- [ ] Runtime target selection comes only from host defaults.
- [ ] Remote-main drift is checked before destructive work.
- [ ] Both lock-freezing flags are used on every installer-side Nix operation consuming the cloned flake.
- [ ] Final toplevel is evaluated before Disko but realized only after target `/mnt/nix` exists.
- [ ] Disko owns topology; impermanence owns only root reset.
- [ ] Partition-label ambiguity fails closed in initrd.
- [ ] Password material never enters Git or the Nix store.
- [ ] Persistent checkout ownership uses evaluated UID/GID.
- [ ] Successful installation powers off and requires manual media removal.
- [ ] Legacy hardware configuration is migration scaffolding only.
- [ ] Real-machine boot is outside this implementation plan.
