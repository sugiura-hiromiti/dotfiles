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
- Deterministic VM/unit/evaluation checks remain under `nix flake check`.
- The full installer lifecycle test is a dedicated networked integration test
  executed outside the Nix build sandbox; network availability is an explicit
  assumption for that test, matching production installation.
- The final system is evaluated before Disko but its full closure is realized
  only after Disko creates the target `/mnt/nix` store.
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
│   ├── build-installer/
│   │   ├── default.nix
│   │   ├── script.nix
│   │   ├── build.nu
│   │   └── tests/
│   └── test-installer-e2e/
│       └── default.nix
├── configurations/
│   └── nixos.nix
├── lib/
│   ├── hosts.nix
│   └── stable-uuid.nix
├── modules/nixos/features/
│   ├── bootstrap-credentials.nix
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

- [ ] **Step 6: Update VM fixtures without changing their disk topology**

Preserve each fixture's existing blank-disk mapping. Do not introduce a global
`/dev/vda` assumption.

For the current fixtures:

```text
storage-provisioning-vm:
  live/root disk = /dev/vda
  blank Disko target = /dev/vdb
  /dev/dotfiles-install-target -> /dev/vdb

impermanence-vm installer:
  installer root = /dev/vdb
  blank Disko target = /dev/vda
  /dev/dotfiles-install-target -> /dev/vda
```

Any future fixture creates the logical symlink to its own existing blank target
disk.

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
- Modify: `nix/profiles/hosts/aarch64-linux-a/nixos.nix`
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

- [ ] **Step 4: Wire the real host's facter-gated target policy now**

Update `aarch64-linux-a/nixos.nix` so these features become enabled only when
`hardware.source == "facter"`:

```nix
dotfiles.features.storage.provisioning.enable = true;
dotfiles.features.preservation.enable = true;
dotfiles.features.impermanence.enable = true;
dotfiles.features.bootstrapCredentials.enable = true;
```

The checked-in legacy host remains safe because the condition is false until a
temporary test or real installer supplies facter state.

This wiring belongs here so the production migration test later in the plan is
non-vacuous and tests the actual intended configuration.

- [ ] **Step 5: Run the focused check and verify the legacy host still evaluates**

- [ ] **Step 6: Commit**

```bash
git add nix/modules/nixos/features/bootstrap-credentials.nix nix/modules/nixos/default.nix nix/profiles/hosts/aarch64-linux-a/nixos.nix nix/tests/nixos/bootstrap-credentials.nix nix/checks.nix
git commit -m "feat: declare facter-gated bootstrap policy"
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

### Task 6: Implement the Two-Phase Installer Transaction

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
- Before Disko: evaluate correctness, but do not realize the large final system closure.
- After Disko: `nixos-install` realizes/fetches the final closure directly into the target store at `/mnt/nix/store`.

- [ ] **Step 1: Write failing operation tests**

Cover:

1. password mismatch;
2. final Nix evaluation failure;
3. ambiguous disk;
4. changed hardware facts;
5. unchanged hardware facts;
6. successful destructive/install tail.

Every failure before Disko asserts:

```bash
test ! -e "$TEST_STATE/disko-called"
test ! -e "$TEST_STATE/nixos-install-called"
```

Changed-facts case asserts exactly one installer commit touching
`facter.json`. Unchanged-facts case asserts installation continues from the
embedded `HEAD` without an empty commit. No case may modify `flake.lock`.

- [ ] **Step 2: Package runtime binaries**

Include exact Nix-store paths for Git, Nix, nixos-facter, nixos-install,
Nushell, systemd-ask-password, mkpasswd, lsblk/findmnt/readlink/mount/umount,
and coreutils.

- [ ] **Step 3: Implement password acquisition before destructive work**

Use `systemd-ask-password` twice, reject empty/mismatched input, hash with
yescrypt, then discard plaintext. Do not write the hash until Disko has mounted
the target persistence filesystem.

- [ ] **Step 4: Implement clean embedded-repository setup**

Clone the bundle, configure only a local installer commit identity, and verify
embedded `HEAD`.

- [ ] **Step 5: Regenerate hardware facts without requiring a commit**

```text
nixos-facter -> host/facter.json
git add host/facter.json
```

If the staged diff is empty, keep embedded `HEAD`.

If the staged diff is non-empty, assert the only changed path is the host
`facter.json` and create:

```text
bootstrap: record installer state
```

Do not stage or modify `flake.lock`.

- [ ] **Step 6: Evaluate the final configuration before wipe**

Use `nix eval` against the path flake and existing lock to force evaluation of
at least:

```text
nixosConfigurations.<target>.config.system.build.toplevel.drvPath
nixosConfigurations.<target>.config.users.users.<primary>.home
nixosConfigurations.<target>.config.dotfiles.features.bootstrapCredentials.hashFile
```

This phase catches Nix syntax/module/assertion/configuration failures but does
not realize the full final system closure.

- [ ] **Step 7: Realize only the Disko provisioning script before wipe**

Build `config.system.build.diskoScript`. This is the comparatively small
provisioning closure needed to cross the destructive boundary; do not build
`system.build.toplevel` here.

- [ ] **Step 8: Resolve and revalidate the safe target disk**

Use Task 5's selector. Immediately before destructive work, verify the selected
device is still the same allowed whole disk and is still not the installer
medium.

- [ ] **Step 9: Execute Disko and materialize the secret**

```text
create /dev/dotfiles-install-target symlink
→ run diskoScript
→ target is mounted below /mnt
→ create resolved password-hash parent under /mnt
→ write hash with mode 0600
```

- [ ] **Step 10: Let nixos-install realize directly into the target store**

Run the final install from the live repository:

```bash
nixos-install \
  --root /mnt \
  --flake "path:$repo#$target" \
  --no-write-lock-file \
  --no-channel-copy \
  --no-root-password
```

Do not pass `--system`: the full toplevel is intentionally not pre-built.
Current `nixos-install` builds the flake using the target store rooted at
`/mnt`, so the physical store is `/mnt/nix/store`, which becomes the
installed `/nix/store` after reboot.

Network access is allowed for locked inputs, substitutes, and builds.

- [ ] **Step 11: Persist the checkout and finish filesystem writes**

Copy the Git checkout to:

```text
/mnt/persist + resolved-home + /dotfiles
```

and chown it to the resolved primary UID/GID.

Do not delete `/mnt` or `/mnt/nix/store`; these are the mounted target
filesystems. Final cleanup is sync + unmount, not wiping.

- [ ] **Step 12: Run operation tests and commit**

```bash
git add nix/installer/install.nu nix/installer/script.nix nix/tests/installer/operation.nix nix/checks.nix
git commit -m "feat: add two-phase bootstrap transaction"
```

---

### Task 7: Add Durable Boot Handoff and Same-ISO Re-entry Protection

**Files:**

- Create: `nix/installer/handoff.nu`
- Create: `nix/tests/installer/handoff.nix`
- Modify: `nix/checks.nix`

**Interfaces:**

- Marker directory on target ESP:
  - `/.dotfiles-installer/`
- Completion marker:
  - `/.dotfiles-installer/completed-<installerId>`
- Marker for the same installer ID means: never Disko; automatically hand off to the installed system.
- A newly built installer ID may deliberately reinstall.
- Installed boot entry is first in persistent UEFI `BootOrder` and also selected as immediate `BootNext`.

- [ ] **Step 1: Write handoff/marker policy tests**

Cover:

- blank disk: destructive install allowed;
- marker for another installer ID: deliberate reinstall allowed;
- marker for same ID: Disko denied and handoff path selected;
- completion marker must be written/flushed before any firmware handoff command;
- handoff failure after marker creation leaves the target guarded.

- [ ] **Step 2: Detect same-ISO completion before destructive installation**

After selecting the target disk, inspect its existing ESP read-only.

If the same installer ID is present:

```text
do not prompt for reinstall work
do not run Disko
→ repair/verify installed boot priority
→ set BootNext
→ reboot or use safe fallback
```

The re-entry path must not strand the user at the installer merely because
formatting is refused.

- [ ] **Step 3: Create and durably flush the marker after successful install**

After `nixos-install` and persistent checkout completion, create:

```text
/mnt/boot/.dotfiles-installer/completed-<installerId>
```

containing host and embedded Git commit.

Then flush the marker and ESP filesystem before attempting any boot-variable
changes. Only a successfully installed system receives the completion marker.

- [ ] **Step 4: Configure persistent and immediate UEFI handoff**

Using `efibootmgr`:

1. create or locate the installed target's UEFI boot entry;
2. place it first in persistent `BootOrder`;
3. set the same entry in `BootNext`;
4. read back and verify both values.

Persistent `BootOrder` handles ordinary later reboots even while the USB/CD
remains attached. `BootNext` handles the immediate first reboot.

- [ ] **Step 5: Define safe fallback**

If UEFI handoff cannot be verified, do not blind-reboot.

Use a Nix-built kexec handoff when available. If neither verified UEFI handoff
nor kexec is possible, leave the installer stopped/failed. Because the marker
was flushed first, another boot of the same ISO cannot wipe the completed
target and will retry handoff.

- [ ] **Step 6: Sync/unmount only after durable completion state**

After marker + handoff state are safe:

```text
sync
→ unmount target filesystems
→ final reboot/kexec
```

Never wipe `/mnt`; it is only the live installer's mount namespace for the
future installed filesystems.

- [ ] **Step 7: Run tests and commit**

```bash
git add nix/installer/handoff.nu nix/tests/installer/handoff.nix nix/checks.nix
git commit -m "feat: guard reentry and persist boot handoff"
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

### Task 11: Add Non-Vacuous Production Checks and a Networked Installer E2E

**Files:**

- Create: `nix/tests/nixos/production-host-impermanence.nix`
- Create: `nix/tests/installer/e2e-vm.nix`
- Create: `nix/tests/installer/fixture-facter.json`
- Create: `nix/apps/test-installer-e2e/default.nix`
- Modify: `nix/flake/apps.nix`
- Modify: `nix/checks.nix`
- Modify only when needed for arguments: `nix/flake/checks.nix`

**Interfaces:**

- Production migration evaluation remains in `nix flake check`.
- Full installer lifecycle execution is exposed as:
  - `nix run .#test-installer-e2e`
- The E2E driver/QEMU runs outside the Nix build sandbox and may assume network access.
- The test uses the real embedded lock and production network-fetch behavior; it never runs `flake update`.

- [ ] **Step 1: Build the real-host migration evaluation**

Take the normalized real `aarch64-linux-a` host, override only hardware state
with fixture facter data, and feed it through the same production NixOS
constructor for every generated runtime target.

Assert:

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

These feature gates already exist from Task 4. Do not defer them to the next
task and do not skip the host because checked-in hardware is still legacy.

- [ ] **Step 2: Keep the full lifecycle test network-realistic**

Do not build a fake offline flake or substitute local input semantics solely for
the test.

The VM runs the same locked flake behavior as production and may use network
access for missing locked inputs/substitutes/builds.

Hardware probing may still be replaced with a deterministic facter fixture so
the test is repeatable with respect to observed machine facts.

- [ ] **Step 3: Expose the test driver outside the build sandbox**

Build the NixOS test driver's `driverInteractive` derivation, but expose an app
that executes:

```text
nixos-test-driver --no-interactive
```

outside the Nix derivation sandbox.

This keeps the VM/test definition Nix-built while allowing the QEMU process to
use normal host networking.

Do not add the network-dependent E2E execution itself to `nix flake check`.

- [ ] **Step 4: Exercise the real two-phase transaction**

Verify:

```text
pre-wipe:
  password
  facter
  optional facter commit
  final Nix evaluation
  Disko-script realization
  disk safety

post-wipe:
  Disko mounts /mnt + /mnt/nix + /mnt/persist + /mnt/boot
  password hash materialized
  nixos-install --flake fetches/builds using network
  final closure lands in /mnt/nix/store
```

The test must not require a pre-format realization of the full final toplevel.

- [ ] **Step 5: Exercise password/authentication**

Supply a known test password through the same ask-password path.

After installed boot prove:
- password login works;
- sudo authentication using the password works;
- authentication still works after an impermanence reboot.

- [ ] **Step 6: Exercise real boot handoff with media still attached**

Use one UEFI VM state with:
- installer ISO attached;
- target disk attached;
- persistent firmware/NVRAM state.

Allow the installer to reboot itself. Do not simulate success by manually
assigning another node's `state_dir`.

Assert persistent `BootOrder` and immediate `BootNext` lead to the installed
system.

- [ ] **Step 7: Exercise same-ISO re-entry**

Force firmware to boot the same ISO after successful installation.

Assert:
- Disko is not invoked;
- no password/reinstallation flow is required;
- completion marker is detected;
- installer automatically repairs/verifies handoff and reaches the installed system.

- [ ] **Step 8: Exercise facter changed/unchanged cases**

Changed facter data creates one local installer commit.

Regenerating byte-identical facter data creates no empty commit and still
permits installation/reinstallation.

- [ ] **Step 9: Verify storage and custom-home behavior**

Check `/@root`, `/@nix`, `/@persist`, persistence/reset behavior, and a
fixture user with:

```nix
homeDirectory = "/srv/tester";
```

whose repository backing path is:

```text
/persist/srv/tester/dotfiles
```

- [ ] **Step 10: Test disk ambiguity**

Two eligible disks without an override must remain untouched.

- [ ] **Step 11: Run deterministic checks**

```bash
nix build -L .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).production-host-impermanence
nix flake check -L
```

- [ ] **Step 12: Run the networked lifecycle integration test**

```bash
nix run .#test-installer-e2e
```

This command explicitly assumes usable network access.

- [ ] **Step 13: Commit**

```bash
git add nix/tests/installer/e2e-vm.nix nix/tests/installer/fixture-facter.json nix/tests/nixos/production-host-impermanence.nix nix/apps/test-installer-e2e nix/flake/apps.nix nix/checks.nix nix/flake/checks.nix
git commit -m "test: cover production and networked installer lifecycle"
```

---

### Task 12: Finalize Host Metadata, Commit, and Build the Real Installer

**Files:**

- Modify: `nix/profiles/hosts/aarch64-linux-a/meta.nix`
- Already wired in Task 4: `nix/profiles/hosts/aarch64-linux-a/nixos.nix`
- Keep during migration: `nix/profiles/hosts/aarch64-linux-a/hardware-configuration.nix`
- Generated only by real installer: `nix/profiles/hosts/aarch64-linux-a/facter.json`
- Modify: `README.org`
- Modify: `flake.nix` comments

**Interfaces:**

- Current legacy ext4 system remains evaluable because Task 4's new feature
  policy is gated on `hardware.source == "facter"`.
- A real installer-generated facter file activates the already-tested Disko +
  preservation + impermanence + credential path.

- [ ] **Step 1: Add explicit installer metadata**

```nix
installer = {
  enable = true;
  diskOverride = null;
};
```

- [ ] **Step 2: Verify the pre-bootstrap real host still evaluates**

Run the current aarch64 target evaluation/build before any real `facter.json`
exists.

- [ ] **Step 3: Update user-facing lifecycle docs**

Document:

```text
Create/recreate:
  nix run .#build-installer -- --host HOST
  boot result/installer-HOST

Install interaction:
  choose administrator password once

Maintain:
  nix run .#update

Full networked installer E2E:
  nix run .#test-installer-e2e
```

Also document:
- install uses the embedded lock and never updates dependencies;
- pre-wipe work evaluates the final config but does not build the full system;
- after Disko, `nixos-install` realizes directly into the future `/nix/store`;
- `/mnt` is only the live installer's mount point and is unmounted, not wiped;
- same ISO cannot format the completed target again and will automatically hand off;
- a fresh ISO ID permits deliberate factory reset;
- password hash stays under `/persist`.

- [ ] **Step 4: Run formatting and all deterministic checks**

```bash
nix run .#fix
git diff --check
nix flake check -L
```

- [ ] **Step 5: Run the networked E2E before final host commit**

```bash
nix run .#test-installer-e2e
```

Fix any demonstrated defect, rerun checks, and only continue when green.

- [ ] **Step 6: Commit all Task 12 source/document changes before invoking the clean-tree builder**

```bash
git add nix/profiles/hosts/aarch64-linux-a/meta.nix README.org flake.nix
git commit -m "feat: finalize facter-backed impermanence bootstrap"
```

Include any other Task-12 file changed by formatting/fixes. After this commit:

```bash
git status --short
```

must be empty.

- [ ] **Step 7: Verify dirty-tree rejection**

Create an untracked probe and ensure `.#build-installer` refuses it, then remove
the probe and verify the tree is clean again.

- [ ] **Step 8: Build the real installer from committed clean state**

```bash
nix run .#build-installer -- --host aarch64-linux-a
```

Expected output link:

```text
result/installer-aarch64-linux-a
```

Because `result/` is ignored:

```bash
git status --short
```

must remain empty.

- [ ] **Step 9: Stop before destructive rollout**

Implementation completion does not include booting the real ISO.

The later operational action is:

```text
boot installer
→ detect same-ISO completion and hand off, OR continue fresh install
→ choose administrator password
→ facter
→ optional facter commit
→ evaluate final configuration
→ fail-closed disk validation
→ Disko wipe/mount
→ persistent password hash
→ nixos-install builds/fetches into /mnt/nix/store
→ persistent Git checkout
→ completion marker + durable flush
→ persistent BootOrder + BootNext
→ one final reboot
→ installed impermanent NixOS
```
