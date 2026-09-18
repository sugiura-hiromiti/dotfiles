# NixOS Impermanence Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a host-specific NixOS installer that freezes dependency selection at ISO-build time, asks only for the administrator secret at install time, records hardware facts, provisions the Disko Btrfs impermanence layout, installs safely, and leaves `.#update` as the only steady-state dependency-update path.

**Architecture:** Nix defines the installer ISO, runtime scripts, user authentication policy, Disko layout, boot-handoff behavior, and tests. Runtime code built by Nix only performs live-machine operations: password input/hashing, facter probing, disk selection, formatting, secret materialization, installation, and boot handoff. Installation never runs `nix flake update`; the committed `flake.lock` embedded in the ISO remains authoritative.

**Tech Stack:** NixOS/nixpkgs, flake-parts, Disko, nixos-facter, preservation, Nushell, systemd, Git, systemd-boot/UEFI tooling, NixOS VM tests.

**Spec:** `docs/superpowers/specs/2026-09-18-nixos-impermanence-bootstrap-design.md`

## Global Constraints

- Installer-build time clean Git `HEAD` plus committed `flake.lock` is the source of truth.
- Installation MUST NOT run `nix flake update` or modify `flake.lock`.
- A host ISO may be built before its `facter.json` exists.
- Final host evaluation happens only after the installer generates `facter.json`.
- Installer-generated Git state is only `facter.json`.
- Secrets never enter Git or the Nix store.
- The primary administrator chooses a password interactively during installation and does not need a post-install `passwd` step.
- Disko is the only owner of installed filesystem topology.
- Impermanence owns only root-reset behavior.
- Preservation remains intentionally narrow.
- Default disk selection is the only internal, non-removable, non-hotplug whole disk other than the installer medium.
- Disk ambiguity fails before destructive work.
- The same installer ISO must never destructively install twice on the same completed target.
- A newly built ISO may deliberately reinstall and wipe the target.
- Installer result symlinks live under the already ignored `result/` directory.
- Repository persistence is derived from the resolved NixOS primary-user home path.
- `.#update` remains non-destructive and is the only normal dependency-update path.
- Tests requiring a VM must follow the repository's existing Linux/KVM gating policy.

---

## File Structure

```text
nix/
├── installer/
│   ├── build.nix
│   ├── default.nix
│   ├── iso.nix
│   ├── script.nix
│   ├── install.nu
│   ├── disk-selector.nu
│   └── handoff.nu
├── apps/
│   └── build-installer/
│       ├── default.nix
│       ├── script.nix
│       ├── build.nu
│       └── tests/
├── configurations/
│   └── nixos.nix
├── lib/
│   ├── hosts.nix
│   └── stable-uuid.nix
├── modules/nixos/features/
│   ├── bootstrap-credentials.nix
│   ├── installer-handoff.nix
│   ├── storage/
│   └── impermanence/
└── tests/
    ├── fixtures/hosts/
    ├── installer/
    └── nixos/
```

---

### Task 1: Model Bootstrap and Hardware Resolution in the Host Registry

**Files:**
- Modify: `nix/lib/hosts.nix`
- Create: `nix/tests/fixtures/hosts/bootstrap-only/meta.nix`
- Create: `nix/tests/fixtures/hosts/legacy/meta.nix`
- Create: `nix/tests/fixtures/hosts/legacy/hardware-configuration.nix`
- Create: `nix/tests/fixtures/hosts/facter/meta.nix`
- Create: `nix/tests/fixtures/hosts/facter/facter.json`
- Create: `nix/tests/lib/hosts-installer.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- Produces normalized host fields:
  - `installer.enable :: bool`
  - `installer.diskOverride :: null | string`
  - `hardware.factsPath :: null | path`
  - `hardware.legacyConfigPath :: null | path`
  - `hardware.source :: "facter" | "legacy" | "unresolved"`
  - `hardware.resolved :: bool`

- [ ] **Step 1: Add fixtures**

Use a minimal NixOS host fixture with `system = "x86_64-linux"`, one UID-1000 user, and `installer.enable = true`.

Legacy fixture marker:

```nix
{
  environment.etc."legacy-hardware-marker".text = "legacy\n";
}
```

Minimal facter fixture:

```json
{
  "version": 2,
  "system": "x86_64-linux",
  "virtualisation": "qemu",
  "hardware": {},
  "smbios": {}
}
```

- [ ] **Step 2: Write failing registry assertions**

Assert unresolved, legacy, and facter sources exactly as specified by the interface.

- [ ] **Step 3: Run the focused check**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).hosts-installer
```

Expected: FAIL before the new fields exist.

- [ ] **Step 4: Implement normalization**

Derive facter/legacy paths with `builtins.pathExists`. Prefer facter over legacy. Validate a non-null disk override as an absolute path.

- [ ] **Step 5: Rerun and commit**

```bash
git add nix/lib/hosts.nix nix/tests/fixtures/hosts nix/tests/lib/hosts-installer.nix nix/checks.nix
git commit -m "feat: model host bootstrap hardware state"
```

---

### Task 2: Centralize Final Hardware Source Selection

**Files:**
- Modify: `nix/configurations/common.nix`
- Modify: `nix/configurations/nixos.nix`
- Modify: `nix/lib/targets.nix`
- Modify: `nix/profiles/hosts/aarch64-linux-a/nixos.nix`
- Create: `nix/tests/nixos/hardware-source.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- Facter is preferred when `hardware.source == "facter"`.
- Legacy generated hardware is migration-only fallback.
- Unresolved NixOS hosts do not appear in normal final `nixosConfigurations`.
- Installer construction may still enumerate unresolved bootstrap-capable hosts.

- [ ] **Step 1: Write the failing facter-vs-legacy test**

Facter case:

```nix
assert system.config.hardware.facter.reportPath == factsPath;
assert !(system.config.environment.etc ? "legacy-hardware-marker");
```

Legacy case:

```nix
assert system.config.environment.etc ? "legacy-hardware-marker";
assert system.config.hardware.facter.reportPath == null;
```

- [ ] **Step 2: Add `hardware` and `installer` to common specialArgs**

Pass the normalized host metadata to host NixOS modules.

- [ ] **Step 3: Add centralized hardware module selection**

Use facter reportPath for facter hosts, import the legacy hardware file only for legacy hosts, and throw for unresolved final systems.

- [ ] **Step 4: Remove direct hardware import from the real host profile**

Delete the `imports = [ ./hardware-configuration.nix ];` line from `aarch64-linux-a/nixos.nix`.

- [ ] **Step 5: Filter unresolved final NixOS target enumeration**

Keep bootstrap enumeration separate.

- [ ] **Step 6: Run focused and full checks, then commit**

```bash
nix flake check -L
git add nix/configurations/common.nix nix/configurations/nixos.nix nix/lib/targets.nix nix/profiles/hosts/aarch64-linux-a/nixos.nix nix/tests/nixos/hardware-source.nix nix/checks.nix
git commit -m "feat: prefer facter hardware configuration"
```

---

### Task 3: Make Disko the Production Storage Owner

**Files:**
- Create: `nix/lib/stable-uuid.nix`
- Modify: `nix/configurations/nixos.nix`
- Modify: `nix/flake/default.nix`
- Modify: `nix/modules/nixos/features/storage/provisioning.nix`
- Modify: `nix/tests/nixos/storage-provisioning.nix`
- Modify: `nix/tests/nixos/storage-provisioning-vm.nix`
- Modify: `nix/tests/nixos/impermanence-vm.nix`

**Interfaces:**
- Production NixOS construction imports the Disko provisioning module.
- Btrfs UUID is deterministic from host identity.
- `provisioning.disk` defaults to `/dev/dotfiles-install-target`.

- [ ] **Step 1: Add deterministic UUID helper**

Create a UUID-shaped value from the first 32 hexadecimal characters of:

```nix
builtins.hashString "sha256" ("dotfiles-btrfs:" + name)
```

- [ ] **Step 2: Make a storage test fail on the logical-device default**

Assert:

```nix
assert disk.device == "/dev/dotfiles-install-target";
```

- [ ] **Step 3: Add the host-derived filesystem UUID default**

Set it from the NixOS target constructor while preserving test overrides.

- [ ] **Step 4: Default Disko's disk option**

```nix
disk = lib.mkOption {
  type = lib.types.str;
  default = "/dev/dotfiles-install-target";
};
```

- [ ] **Step 5: Import Disko in production construction**

Pass the Disko flake input into `nix/configurations/nixos.nix`.

- [ ] **Step 6: Update VM fixtures**

Tests using the logical device create:

```bash
ln -s /dev/vda /dev/dotfiles-install-target
```

before executing Disko.

- [ ] **Step 7: Run storage and impermanence checks, then commit**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).storage-provisioning
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).storage-provisioning-vm
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).impermanence-vm
git add nix/lib/stable-uuid.nix nix/configurations/nixos.nix nix/flake/default.nix nix/modules/nixos/features/storage/provisioning.nix nix/tests/nixos
git commit -m "feat: make disko own production storage"
```

---

### Task 4: Declare Persistent Administrator Credentials in Nix

**Files:**
- Create: `nix/modules/nixos/features/bootstrap-credentials.nix`
- Modify: `nix/modules/nixos/default.nix`
- Create: `nix/tests/nixos/bootstrap-credentials.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- Option: `dotfiles.features.bootstrapCredentials.enable :: bool`
- Read-only option: `dotfiles.features.bootstrapCredentials.hashFile :: string`
- When enabled:
  - primary user `hashedPasswordFile` is the persistent secret file;
  - `users.mutableUsers = false`.
- Default hash path:
  - `/persist/secrets/users/<primary>.password`

- [ ] **Step 1: Write the failing module test**

For primary user `tester`, assert:

```nix
assert system.config.users.mutableUsers == false;
assert system.config.users.users.tester.hashedPasswordFile ==
  "/persist/secrets/users/tester.password";
assert system.config.dotfiles.features.bootstrapCredentials.hashFile ==
  "/persist/secrets/users/tester.password";
```

- [ ] **Step 2: Implement the module**

Use the existing `accounts.primary` special argument. Do not place password material in a Nix string; only declare the runtime file path.

- [ ] **Step 3: Import it from the NixOS module root**

- [ ] **Step 4: Run the focused check and commit**

```bash
git add nix/modules/nixos/features/bootstrap-credentials.nix nix/modules/nixos/default.nix nix/tests/nixos/bootstrap-credentials.nix nix/checks.nix
git commit -m "feat: declare persistent administrator credentials"
```

---

### Task 5: Implement Fail-Closed Disk Selection

**Files:**
- Create: `nix/installer/disk-selector.nu`
- Create: `nix/tests/installer/disk-selector.nix`
- Create: `nix/tests/installer/fixtures/one-disk.json`
- Create: `nix/tests/installer/fixtures/no-disk.json`
- Create: `nix/tests/installer/fixtures/two-disks.json`
- Modify: `nix/checks.nix`

**Interfaces:**
- Function: `select-install-disk lsblk_json disk_override installer_parent -> string`
- Automatic candidate:
  - `TYPE=disk`
  - non-removable
  - non-hotplug
  - not installer parent
- Explicit overrides are canonicalized with `readlink -f`.

- [ ] **Step 1: Add lsblk fixtures and failing assertions**

```nu
assert equal (select-install-disk $one null null) "/dev/vda"
assert error { select-install-disk $none null null }
assert error { select-install-disk $two null null }
assert equal (select-install-disk $two "/dev/vdb" null) "/dev/vdb"
assert error { select-install-disk $two "/dev/vda" "/dev/vda" }
```

- [ ] **Step 2: Implement selection and explicit error messages**

Ambiguity errors list the eligible candidates.

- [ ] **Step 3: Run and commit**

```bash
git add nix/installer/disk-selector.nu nix/tests/installer nix/checks.nix
git commit -m "feat: add fail-closed installer disk selection"
```

---

### Task 6: Implement the Installer Transaction Without Dependency Updates

**Files:**
- Create: `nix/installer/install.nu`
- Create: `nix/installer/script.nix`
- Create: `nix/tests/installer/operation.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- Installer constants:
  - host
  - targetName
  - primaryAccount
  - diskOverride
  - installerId
- Embedded repository bundle: `/iso/dotfiles.bundle`.
- Installer queries the final NixOS config for:
  - primary user home;
  - bootstrap credential hash-file path.
- Installer never invokes `nix flake update`.

- [ ] **Step 1: Write failing operation tests**

Cover:
1. password mismatch;
2. target build failure;
3. ambiguous disk;
4. successful transaction.

Every failure before Disko asserts:

```bash
test ! -e "$TEST_STATE/disko-called"
test ! -e "$TEST_STATE/nixos-install-called"
```

Success asserts the local installer commit changes `facter.json` but not `flake.lock`.

- [ ] **Step 2: Package runtime binaries**

Include exact Nix-store paths for:
- Git;
- Nix;
- nixos-facter;
- nixos-install;
- Nushell;
- systemd-ask-password;
- mkpasswd;
- lsblk/findmnt/readlink/mount/umount;
- coreutils.

- [ ] **Step 3: Implement password acquisition before destructive work**

Use `systemd-ask-password` twice.

Reject:
- empty password;
- mismatch.

Hash via stdin:

```bash
printf '%s\n' "$password" | mkpasswd --method=yescrypt --stdin
```

Keep only the resulting hash after comparison/hashing.

Do not write the hash until Disko has mounted `/persist`.

- [ ] **Step 4: Implement clean embedded-repository setup**

Clone the bundle, configure only a local installer commit identity, and verify `HEAD`.

- [ ] **Step 5: Generate and commit hardware facts only**

```text
nixos-facter -> host/facter.json
git add host/facter.json
```

Do not stage or change `flake.lock`.

- [ ] **Step 6: Build using the embedded lock**

Build:
- final `system.build.toplevel`;
- final `system.build.diskoScript`.

No `--update-input`, `flake update`, or lock-writing command is allowed.

- [ ] **Step 7: Query final runtime paths from Nix**

Evaluate:

```text
nixosConfigurations.<target>.config.users.users.<primary>.home
nixosConfigurations.<target>.config.dotfiles.features.bootstrapCredentials.hashFile
```

Derive the persistent checkout destination as:

```text
/mnt/persist + resolved-home + /dotfiles
```

- [ ] **Step 8: Commit `facter.json`**

Commit message:

```text
bootstrap: record installer state
```

Assert `git diff HEAD^ --name-only` is exactly the host `facter.json`.

- [ ] **Step 9: Resolve safe target disk**

Run the Task 5 selector only after target builds succeed.

- [ ] **Step 10: Execute the destructive tail**

```text
create /dev/dotfiles-install-target symlink
→ run diskoScript
→ mkdir parent of resolved password-hash path under /mnt
→ write hash mode 0600
→ nixos-install --root /mnt --system <toplevel> --no-channel-copy --no-root-password
→ copy Git checkout to resolved persistent checkout path
→ chown checkout to resolved primary user UID/GID
→ sync
```

The NixOS user password is supplied by `hashedPasswordFile`; `--no-root-password` is acceptable because root login is not the administrator authentication path.

- [ ] **Step 11: Run operation tests and commit**

```bash
git add nix/installer/install.nu nix/installer/script.nix nix/tests/installer/operation.nix nix/checks.nix
git commit -m "feat: add locked bootstrap transaction"
```

---

### Task 7: Add Boot Handoff and Same-ISO Re-entry Protection

**Files:**
- Create: `nix/installer/handoff.nu`
- Create: `nix/modules/nixos/features/installer-handoff.nix`
- Modify: `nix/modules/nixos/default.nix`
- Create: `nix/tests/installer/handoff.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- Marker directory on target ESP:
  - `/.dotfiles-installer/`
- Completion marker:
  - `/.dotfiles-installer/completed-<installerId>`
- Same installer ID finding its completed marker MUST refuse Disko.
- Newly built installer ID is allowed to reinstall.
- Installed system keeps the marker; safety does not depend on media removal.

- [ ] **Step 1: Write marker-policy tests**

Test pure helper behavior:
- blank disk: no block;
- marker for same ID: destructive install denied;
- marker for another ID: install allowed.

- [ ] **Step 2: Implement non-destructive ESP marker discovery**

Before Disko, inspect existing child partitions of the selected disk. When an EFI System Partition exists, mount it read-only in a temporary directory and check for the same installer ID.

Unmount before continuing.

- [ ] **Step 3: Implement marker creation after installation**

After `nixos-install`, create on the mounted target ESP:

```text
/.dotfiles-installer/completed-<installerId>
```

containing host and embedded Git commit for diagnostics.

- [ ] **Step 4: Add automatic UEFI handoff**

Include `efibootmgr` in installer tooling.

After installation:
1. identify the target ESP partition;
2. create or find a UEFI boot entry for the installed removable/systemd-boot EFI loader;
3. set that entry as `BootNext`;
4. read EFI variables back and verify the intended entry is `BootNext`.

Only then allow ordinary reboot.

- [ ] **Step 5: Define fallback behavior**

If UEFI one-shot handoff cannot be established, do not perform an unsafe blind reboot.

Use a Nix-built kexec handoff when the target exposes a usable kexec script/tree. If neither verified UEFI handoff nor kexec is available, leave the installer failed/stopped without rerunning Disko; the same-ID marker makes subsequent accidental ISO boots non-destructive.

- [ ] **Step 6: Add installed-system marker awareness module**

The installed module does not delete the same-ID completion marker. It may expose the marker path/status for diagnostics, but the persistent guard remains so the same physical ISO cannot wipe the completed installation later.

- [ ] **Step 7: Run tests and commit**

```bash
git add nix/installer/handoff.nu nix/modules/nixos/features/installer-handoff.nix nix/modules/nixos/default.nix nix/tests/installer/handoff.nix nix/checks.nix
git commit -m "feat: guard installer reentry and hand off boot"
```

---

### Task 8: Build the Host-Specific Installer ISO

**Files:**
- Create: `nix/installer/iso.nix`
- Create: `nix/installer/default.nix`
- Create: `nix/installer/build.nix`
- Create: `nix/flake/installers.nix`
- Modify: `nix/flake/default.nix`
- Create: `nix/tests/installer/iso-eval.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- `self.lib.mkInstallerIso { host; repositoryBundle; installerId; }`
- ISO evaluates without `facter.json`.
- Installer uses the host's existing default theme/session target naming.
- ISO enables flakes declaratively.

- [ ] **Step 1: Write failing ISO evaluation assertions**

Assert:
- bootstrap-only host ISO evaluates;
- `nix-command` and `flakes` are in `nix.settings.experimental-features`;
- installer script receives the host and installer ID.

- [ ] **Step 2: Construct the minimal ISO**

Import NixOS's minimal installation CD module.

Set:

```nix
nix.settings.experimental-features = [
  "nix-command"
  "flakes"
];
```

Include:
- Git;
- Nix;
- nixos-facter;
- Nushell;
- mkpasswd;
- util-linux/efibootmgr;
- installer script.

Embed `dotfiles.bundle` using `isoImage.contents`.

- [ ] **Step 3: Configure installer service for interactive secret input**

The service must have console access for `systemd-ask-password`, wait for network-online where needed for locked fetches, and remain failed in the live environment on any installer error.

Do not use unconditional `ExecStartPost=reboot`; reboot/handoff is owned by Task 7 and only occurs after verified safety.

- [ ] **Step 4: Export the dynamic ISO constructor**

Expose `lib.mkInstallerIso`; do not expose a static ISO package that cannot carry build-machine Git history.

- [ ] **Step 5: Add impure bridge `build.nix`**

It accepts:
- repository path;
- host;
- bundle path;
- installer ID.

It calls the flake's `mkInstallerIso`.

- [ ] **Step 6: Run checks and commit**

```bash
git add nix/installer/iso.nix nix/installer/default.nix nix/installer/build.nix nix/flake/installers.nix nix/flake/default.nix nix/tests/installer/iso-eval.nix nix/checks.nix
git commit -m "feat: add host-specific installer iso"
```

---

### Task 9: Add Clean-Tree `build-installer`

**Files:**
- Create: `nix/apps/build-installer/default.nix`
- Create: `nix/apps/build-installer/script.nix`
- Create: `nix/apps/build-installer/build.nu`
- Create: `nix/apps/build-installer/tests/default.nix`
- Create: `nix/apps/build-installer/tests/run.sh`
- Modify: `nix/flake/apps.nix`
- Modify: `nix/checks.nix`

**Interfaces:**
- Command:
  - `nix run .#build-installer -- --host HOST`
- Output link:
  - `result/installer-HOST`
- Each build receives a fresh installer UUID.
- Bundle contains exact `HEAD` and reachable history.

- [ ] **Step 1: Write failing wrapper tests**

Test:
- clean repository succeeds;
- tracked modification fails;
- staged modification fails;
- untracked file fails;
- bundle verifies and contains exact HEAD;
- installer IDs differ between two successful fixture invocations;
- output link is under `result/` and therefore does not appear in `git status --porcelain --untracked-files=all`.

- [ ] **Step 2: Enforce cleanliness**

Reject any output from:

```bash
git status --porcelain=v1 --untracked-files=all
```

- [ ] **Step 3: Create bundle**

```bash
git bundle create "$tmp/dotfiles.bundle" HEAD
git bundle verify "$tmp/dotfiles.bundle"
```

- [ ] **Step 4: Generate installer ID**

Use `uuidgen` from the app's Nix-built runtime dependencies.

The ID is artifact safety metadata and is passed into ISO construction; it is not committed.

- [ ] **Step 5: Build to the ignored result directory**

```bash
mkdir -p "$repository/result"
nix build --impure \
  --file "$repository/nix/installer/build.nix" \
  --argstr repository "$repository" \
  --argstr host "$host" \
  --argstr repositoryBundle "$tmp/dotfiles.bundle" \
  --argstr installerId "$installer_id" \
  --out-link "$repository/result/installer-$host"
```

- [ ] **Step 6: Run tests and commit**

```bash
git add nix/apps/build-installer nix/flake/apps.nix nix/checks.nix
git commit -m "feat: add clean installer build entry point"
```

---

### Task 10: Preserve `.#update` as the Only Dependency-Update Path

**Files:**
- Modify: `nix/apps/update/tests/run.sh`
- Modify only if demonstrated necessary: `nix/apps/update/operation.nu`
- Modify installer operation tests to reject any `flake update` invocation

**Interfaces:**
- Local `HEAD` may be ahead of origin.
- Installer does not update dependencies.
- `.#update` continues to update `flake.lock`.

- [ ] **Step 1: Add local-ahead-of-remote update regression**

Create a remote baseline, add a local-only commit, run the update fixture, and assert update succeeds.

- [ ] **Step 2: Add installer no-update regression**

The installer fake `nix` command fails the test if arguments match `flake update` or any lock-writing update operation.

- [ ] **Step 3: Run update and installer operation checks**

- [ ] **Step 4: Commit**

```bash
git add nix/apps/update/tests/run.sh nix/tests/installer/operation.nix
git commit -m "test: separate installer from dependency updates"
```

Only include `operation.nu` if the regression proves a production bug.

---

### Task 11: Add Non-Vacuous Production and Offline Lifecycle Tests

**Files:**
- Create: `nix/tests/nixos/production-host-impermanence.nix`
- Create: `nix/tests/installer/e2e-vm.nix`
- Create: `nix/tests/installer/fixture-flake.nix`
- Create: `nix/tests/installer/fixture-facter.json`
- Modify: `nix/checks.nix`
- Modify only when needed for arguments: `nix/flake/checks.nix`

**Interfaces:**
- Production migration test uses the actual `aarch64-linux-a` host/profile composition with fixture facter state.
- E2E VM requires no GitHub/network input resolution.
- E2E uses real Nix build, Disko, nixos-install, preservation, impermanence, authentication, and boot handoff.

- [ ] **Step 1: Build the real-host migration evaluation**

Take the normalized real `aarch64-linux-a` host and replace only its hardware state with a test facter report.

Feed that temporary host through the same production NixOS constructor for every generated runtime target.

Assert for each target:

```nix
assert config.hardware.facter.reportPath != null;
assert config.dotfiles.features.storage.provisioning.enable;
assert config.disko.enableConfig;
assert config.fileSystems."/".fsType == "btrfs";
assert config.fileSystems."/nix".fsType == "btrfs";
assert config.fileSystems."/persist".fsType == "btrfs";
assert config.dotfiles.features.impermanence.enable;
assert config.dotfiles.features.bootstrapCredentials.enable;
```

Do not skip the host because the checked-in repository is still legacy.

- [ ] **Step 2: Create an offline fixture flake**

The VM fixture flake contains no remote inputs.

Its `flake.nix` is generated by the outer Nix test and imports the already-resolved store paths for:
- nixpkgs;
- Disko;
- preservation;
- the repository modules under test.

All these source paths are explicit derivation dependencies of the VM test.

The fixture therefore allows:

```bash
nix build path:/fixture#nixosConfigurations.test.config.system.build.toplevel
```

with network disabled.

- [ ] **Step 3: Use real installer transaction with deterministic test inputs**

Use real:
- Git bundle clone;
- Nix final-system build;
- Disko;
- nixos-install;
- password-hash file materialization.

Replace only physical facter probing with a deterministic facter fixture generator.

- [ ] **Step 4: Exercise interactive password flow**

Provide a known test password through the same `systemd-ask-password` mechanism or its test agent.

After installed boot assert:
- the user can authenticate using the fixture password;
- `sudo` succeeds using that password or the configured test PAM interaction;
- no password setup command is required after boot.

- [ ] **Step 5: Test automatic boot handoff without swapping VM identity**

Use a UEFI VM with ISO and target disk both attached.

Let the installer finish and shut down/reboot via its real handoff logic.

Restart/reconnect the same VM state with:
- same disk;
- same ISO still attached;
- same firmware/NVRAM state.

Do not assign a separate target node's `state_dir`.

Assert the installed disk boots and the installer does not execute Disko a second time.

- [ ] **Step 6: Test same-ISO guard explicitly**

Force the firmware to boot the same ISO again after successful installation.

Assert the matching installer-ID marker causes the installer to refuse Disko.

- [ ] **Step 7: Verify storage/reset/persistence**

Check:
- `/@root`;
- `/@nix`;
- `/@persist`;
- disposable root marker disappears after another boot;
- persisted marker survives;
- administrator password still works after root reconstruction.

- [ ] **Step 8: Test custom home path**

Create a fixture primary user with:

```nix
homeDirectory = "/srv/tester";
```

Assert the persistent repository exists at:

```text
/persist/srv/tester/dotfiles
```

and appears at `/srv/tester/dotfiles` through preservation after boot.

- [ ] **Step 9: Test disk ambiguity**

Two eligible disks with no override must leave both unpartitioned by the installer.

- [ ] **Step 10: Run focused checks and commit**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).production-host-impermanence
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).installer-e2e-vm
git add nix/tests/installer nix/tests/nixos/production-host-impermanence.nix nix/checks.nix nix/flake/checks.nix
git commit -m "test: cover production and installer lifecycle"
```

---

### Task 12: Enable the Real Host and Verify the Rollout Boundary

**Files:**
- Modify: `nix/profiles/hosts/aarch64-linux-a/meta.nix`
- Modify: `nix/profiles/hosts/aarch64-linux-a/nixos.nix`
- Keep during migration: `nix/profiles/hosts/aarch64-linux-a/hardware-configuration.nix`
- Generated only by real installer: `nix/profiles/hosts/aarch64-linux-a/facter.json`
- Modify: `README.org`
- Modify: `flake.nix` comments

**Interfaces:**
- Pre-bootstrap ext4 system remains evaluable through legacy hardware fallback.
- Once installer-generated facter exists, real target enables Disko, preservation, impermanence, credentials, and handoff support.

- [ ] **Step 1: Add explicit installer metadata**

```nix
installer = {
  enable = true;
  diskOverride = null;
};
```

- [ ] **Step 2: Gate migration-sensitive features on facter**

The host profile enables, only when `hardware.source == "facter"`:

```nix
dotfiles.features.storage.provisioning.enable = true;
dotfiles.features.preservation.enable = true;
dotfiles.features.impermanence.enable = true;
dotfiles.features.bootstrapCredentials.enable = true;
dotfiles.features.installerHandoff.enable = true;
```

The current legacy installation therefore never interprets its ext4 root as the future Btrfs layout during a normal `.#update`.

- [ ] **Step 3: Verify pre-bootstrap host still builds**

Run the current aarch64 target check before any real `facter.json` exists.

- [ ] **Step 4: Update user-facing lifecycle docs**

Document only:

```text
Create/recreate:
  nix run .#build-installer -- --host HOST
  boot result/installer-HOST

Install interaction:
  choose administrator password once

Maintain:
  nix run .#update
```

Document:
- install uses embedded lock and never updates dependencies;
- same ISO cannot destructively reinstall the completed target;
- building a fresh ISO creates a new installer ID and permits deliberate reinstall;
- target disk is fully wiped;
- password hash stays under `/persist`.

- [ ] **Step 5: Run formatting and complete check suite**

```bash
nix run .#fix
git diff --check
nix flake check -L
```

- [ ] **Step 6: Verify dirty-tree rejection**

Create an untracked probe and ensure `.#build-installer` refuses it, then remove the probe.

- [ ] **Step 7: Build the real installer from clean state**

```bash
nix run .#build-installer -- --host aarch64-linux-a
```

Expected output link:

```text
result/installer-aarch64-linux-a
```

Afterward:

```bash
git status --short
```

must still be empty.

- [ ] **Step 8: Stop before destructive rollout**

Implementation completion does not include booting the real ISO.

The later operational action is:

```text
boot installer
→ enter administrator password
→ facter
→ build using embedded flake.lock
→ fail-closed disk selection
→ Disko wipe
→ persistent password hash
→ nixos-install
→ persistent Git checkout
→ installer-ID marker
→ verified boot handoff
→ installed impermanent NixOS
```

- [ ] **Step 9: Commit**

```bash
git add nix/profiles/hosts/aarch64-linux-a/meta.nix nix/profiles/hosts/aarch64-linux-a/nixos.nix README.org flake.nix
git commit -m "feat: enable facter-backed impermanence bootstrap"
```
