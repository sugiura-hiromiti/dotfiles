# NixOS Impermanence Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans.

**Goal:** Implement
`docs/superpowers/specs/2026-09-18-nixos-impermanence-bootstrap-design.md`.
The spec owns behavior/safety; this plan owns implementation order and tests.

## Verification

```bash
checkSystem=$(nix eval --raw --impure --expr builtins.currentSystem)
nix eval --no-update-lock-file --raw .#checks.$checkSystem.non-vm.drvPath
nix eval --no-update-lock-file --option allow-import-from-derivation false --raw .#checks.$checkSystem.installer-e2e.drvPath
nix flake check --no-build --no-update-lock-file .
nix build --no-update-lock-file -L .#checks.$checkSystem.non-vm

# Lifecycle checks (KVM when available, otherwise QEMU software emulation)
nix flake check --no-update-lock-file -L .
```

On Linux, first evaluate the non-VM aggregate derivation with normal IFD
enabled. This may build configuration inputs read during evaluation, but does
not build the aggregate or run a VM. Then instantiate the installer test with
IFD disabled. The second `nix eval` writes derivations for the ISO's offline
build closure without building the ISO or running a VM. Hosted Linux CI
performs both preparation steps before the read-only evaluation gate.

---

## Task 1: Final NixOS model and verification split

**Files**

- Create: `nix/modules/nixos/features/storage/layout.nix`
- Modify: storage/impermanence/Preservation NixOS modules
- Modify: `nix/configurations/nixos.nix`
- Modify: host/target libraries and flake configuration/check/CI modules
- Modify: `nix/ci/default.nix`, `nix/checks.nix`
- Modify: NixOS structural/impermanence tests
- Delete: obsolete public storage/root-reset surfaces and duplicate VM tests

### 1.1 Storage and root reset

- [x] Define fixed partition label, subvolumes, and installer disk alias once.
- [x] Make Disko consume that layout directly.
- [x] Internalize root reset under impermanence.
- [x] Give the initrd reset service its executable dependencies.
- [x] Test root-device selection for 0/1/2 matching
      `PARTLABEL=dotfiles-system` devices.
- [x] Keep one behavioral impermanence VM for root reset + persistence.

### 1.2 Final-system and Preservation policy

- [x] Centralize facter, storage, preservation, impermanence, authentication, and
      boot policy in the constructed NixOS configuration.
- [x] Set canonical facter and persistent-password paths.
- [x] Preserve the primary user's `dotfiles` directory.
- [x] Export installer metadata for the effective administrator, boot settings,
      and physical Preservation backing path.
- [x] Assert those effective contracts after module merging.
- [x] Leave host profiles with host-specific policy only.

### 1.3 Facter readiness

- [x] Make the host registry own canonical facter-path helpers.
- [x] Derive declared and facter-ready NixOS target sets once.
- [x] Export final NixOS configurations/checks/CI from the ready set.
- [x] Keep installer-package discovery on declared same-system hosts.
- [x] Keep default-target selection in the target model.

### 1.4 Verification split

- [x] Classify checks once as non-VM or VM-backed.
- [x] Expose `checks.<system>.non-vm` as the aggregate non-VM gate.
- [x] Hosted Linux CI runs evaluation + the non-VM aggregate only.
- [x] Allow lifecycle tests to fall back to QEMU software emulation.

---

## Task 2: Installer transaction

**Files**

- Create: `nix/installer/install.nu`
- Create: `nix/installer/script.nix`
- Create: `nix/tests/installer/runtime.nix`
- Modify: `nix/checks.nix`

### 2.1 Runtime inputs

- [x] Package the installer with host, default target, primary account, immutable
      base source, canonical facter path, and EFI architecture.
- [x] Include required runtime tools.
- [x] Use `--no-update-lock-file` for every installer flake operation.

### 2.2 Post-facter source

Each invocation:

- [x] recreates installer-owned runtime state from the immutable base;
- [x] makes the working tree owner-writable while preserving executable bits;
- [x] collects and hashes the administrator password;
- [x] generates facter at the canonical path; and
- [x] adds the completed tree to the Nix store once and roots the returned path.

Metadata evaluation, Disko realization, and installation all use that exact
post-facter store path.

### 2.3 Destructive barrier

- [x] Evaluate and validate administrator, Preservation, and boot metadata.
- [x] Realize the Disko script from the same post-facter source.
- [x] Require exactly one eligible disk from
      `lsblk --json --output PATH,TYPE,RM,HOTPLUG`.
- [x] Create `/dev/dotfiles-install-target` only after those checks succeed.
- [x] Treat unexpected non-symlink objects at the alias path as errors.

### 2.4 Install and persist

- [x] Run Disko and validate expected mountpoints.
- [x] Create `/mnt/persist/etc/dotfiles` as `root:root 0700`.
- [x] Atomically install the yescrypt hash as `root:root 0600`.
- [x] Run `nixos-install --flake` from the post-facter source.
- [x] Verify the fallback EFI loader.
- [x] Copy dotfiles to `/mnt` + the evaluated Preservation backing path.
- [x] Restore owner-write permission, preserve executable bits, and chown to the
      evaluated UID:GID.
- [x] Sync, unmount, and power off.

The installer service uses `UMask=0077`.

### 2.5 Runtime tests

Prove:

- [x] fresh retry state;
- [x] facter placement;
- [x] one post-facter source reused by validation/Disko/install;
- [x] later working-tree mutation cannot affect that source;
- [x] stale/incomplete locks fail and every flake command uses
      `--no-update-lock-file`;
- [x] invalid metadata and Disko-realization failure remain pre-destructive;
- [x] disk cardinality is fail-closed;
- [x] alias-path handling is safe;
- [x] service umask preserves private credentials while system directories
      remain traversable;
- [x] `nixos-install` inherits the selected Nix tools through `PATH`; and
- [x] the ISO check builds the installer and validates its executable dependencies.

---

## Task 3: Source staging, installer ISO, and lifecycle E2E

**Files**

- Create: `nix/installer/iso.nix`
- Create: `nix/flake/installer.nix`
- Create: `nix/apps/build-installer/{default.nix,build.nu,tests/run.sh}`
- Create: `nix/tests/installer/e2e.nix`
- Modify: flake apps/default/checks, `README.org`, `flake.nix`

### 3.1 Capture the base source

`build-installer` owns source selection:

- [x] enumerate the current versioned paths with JJ;
- [x] copy their current filesystem contents to a fresh stage outside the
      checkout, preserving paths, symlinks, and executable bits; and
- [x] build directly from
      `path:<stage>#installer-HOST --no-link --print-out-paths
  --no-update-lock-file`.

The staged flake's `self.outPath` is the immutable base source carried by the
ISO.

Source tests prove:

- [x] modified versioned contents are included;
- [x] ignored/unversioned contents are excluded and cannot change source
      identity; and
- [x] symlinks and executable bits survive staging.

### 3.2 Installer packages and ISO

- [x] Generate `installer-<host>` packages for declared same-system NixOS
      hosts from the staged flake source.
- [x] A facter-less declared host still produces its installer package.
- [x] Configure the minimal installation ISO with required Nix CLI features.
- [x] Reserve tty1 for the installer and tty2 for diagnostics.
- [x] Start after/wanting `network-online.target`.
- [x] Set installer-service `UMask=0077`.
- [x] Print a concrete tty2 recovery/restart instruction on pre-Disko
      connectivity failure.

### 3.3 Lifecycle E2E

Implementation is present. Lifecycle verification is in progress.

Use `pkgs.testers.runNixOSTest` with UEFI, the actual installer ISO, one blank
eligible disk, and all required source/store dependencies supplied inside the
hermetic test environment.

Verify:

```text
boot ISO
→ installer transaction
→ fixed Disko layout
→ password file root:root 0600 before unmount
→ Preservation backing dotfiles exist before unmount
→ fallback EFI loader
→ poweroff
→ boot installed disk without ISO
→ login + sudo
→ password file still root:root 0600
→ preserved dotfiles visible and user-writable
→ create disposable + persistent markers
→ reboot
→ disposable state gone; persistent state survives
```

### 3.4 Operator documentation

Document only:

```text
edit/version dotfiles
→ nix run .#build-installer -- --host HOST
→ use reported installer store output
→ write/attach ISO
→ boot and enter password
→ poweroff
→ remove media
→ boot installed system
```
