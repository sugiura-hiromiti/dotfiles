# NixOS Impermanence Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans.

**Goal:** Implement
`docs/superpowers/specs/2026-09-18-nixos-impermanence-bootstrap-design.md`.
The spec owns behavior/safety; this plan owns implementation order and tests.

## Verification

```bash
nix flake check --no-build .
nix build -L   .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).non-vm

# KVM-capable builder only
nix flake check -L .
```

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

- [ ] Define fixed partition label, subvolumes, and installer disk alias once.
- [ ] Make Disko consume that layout directly.
- [ ] Internalize root reset under impermanence.
- [ ] Give the initrd reset service its executable dependencies.
- [ ] Test root-device selection for 0/1/2 matching
  `PARTLABEL=dotfiles-system` devices.
- [ ] Keep one behavioral impermanence VM for root reset + persistence.

### 1.2 Final-system and Preservation policy

- [ ] Centralize facter, storage, preservation, impermanence, authentication, and
  boot policy in the constructed NixOS configuration.
- [ ] Set canonical facter and persistent-password paths.
- [ ] Preserve the primary user's `dotfiles` directory.
- [ ] Export installer metadata for the effective administrator, boot settings,
  and physical Preservation backing path.
- [ ] Assert those effective contracts after module merging.
- [ ] Leave host profiles with host-specific policy only.

### 1.3 Facter readiness

- [ ] Make the host registry own canonical facter-path helpers.
- [ ] Derive declared and facter-ready NixOS target sets once.
- [ ] Export final NixOS configurations/checks/CI from the ready set.
- [ ] Keep installer-package discovery on declared same-system hosts.
- [ ] Keep default-target selection in the target model.

### 1.4 Verification split

- [ ] Classify checks once as non-VM or VM-backed.
- [ ] Expose `checks.<system>.non-vm` as the aggregate non-VM gate.
- [ ] Keep VM tests KVM-requiring.
- [ ] Hosted Linux CI runs evaluation + the non-VM aggregate only.
- [ ] Lifecycle tests run on a KVM-capable builder.

---

## Task 2: Installer transaction

**Files**

- Create: `nix/installer/install.nu`
- Create: `nix/installer/script.nix`
- Create: `nix/tests/installer/runtime.nix`
- Modify: `nix/checks.nix`

### 2.1 Runtime inputs

- [ ] Package the installer with host, default target, primary account, immutable
  base source, canonical facter path, and EFI architecture.
- [ ] Include required runtime tools.
- [ ] Use `--no-update-lock-file` for every installer flake operation.

### 2.2 Post-facter source

Each invocation:

- [ ] recreates installer-owned runtime state from the immutable base;
- [ ] makes the working tree owner-writable while preserving executable bits;
- [ ] collects and hashes the administrator password;
- [ ] generates facter at the canonical path; and
- [ ] adds the completed tree to the Nix store once and roots the returned path.

Metadata evaluation, Disko realization, and installation all use that exact
post-facter store path.

### 2.3 Destructive barrier

- [ ] Evaluate and validate administrator, Preservation, and boot metadata.
- [ ] Realize the Disko script from the same post-facter source.
- [ ] Require exactly one eligible disk from
  `lsblk --json --output PATH,TYPE,RM,HOTPLUG`.
- [ ] Create `/dev/dotfiles-install-target` only after those checks succeed.
- [ ] Treat unexpected non-symlink objects at the alias path as errors.

### 2.4 Install and persist

- [ ] Run Disko and validate expected mountpoints.
- [ ] Create `/mnt/persist/etc/dotfiles` as `root:root 0700`.
- [ ] Atomically install the yescrypt hash as `root:root 0600`.
- [ ] Run `nixos-install --flake` from the post-facter source.
- [ ] Verify the fallback EFI loader.
- [ ] Copy dotfiles to `/mnt` + the evaluated Preservation backing path.
- [ ] Restore owner-write permission, preserve executable bits, and chown to the
  evaluated UID:GID.
- [ ] Sync, unmount, and power off.

The installer service uses `UMask=0077`.

### 2.5 Runtime tests

Prove:

- [ ] fresh retry state;
- [ ] facter placement;
- [ ] one post-facter source reused by validation/Disko/install;
- [ ] later working-tree mutation cannot affect that source;
- [ ] stale/incomplete locks fail and every flake command uses
  `--no-update-lock-file`;
- [ ] invalid metadata and Disko-realization failure remain pre-destructive;
- [ ] disk cardinality is fail-closed; and
- [ ] alias-path handling is safe.

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

- [ ] enumerate the current versioned paths with JJ;
- [ ] copy their current filesystem contents to a fresh stage outside the
  checkout, preserving paths, symlinks, and executable bits; and
- [ ] build directly from
  `path:<stage>#installer-HOST --no-link --print-out-paths
  --no-update-lock-file`.

The staged flake's `self.outPath` is the immutable base source carried by the
ISO.

Source tests prove:

- [ ] modified versioned contents are included;
- [ ] ignored/unversioned contents are excluded and cannot change source
  identity; and
- [ ] symlinks and executable bits survive staging.

### 3.2 Installer packages and ISO

- [ ] Generate `installer-<host>` packages for declared same-system NixOS
  hosts from the staged flake source.
- [ ] A facter-less declared host still produces its installer package.
- [ ] Configure the minimal installation ISO with required Nix CLI features.
- [ ] Reserve tty1 for the installer and tty2 for diagnostics.
- [ ] Start after/wanting `network-online.target`.
- [ ] Set installer-service `UMask=0077`.
- [ ] Print a concrete tty2 recovery/restart instruction on pre-Disko
  connectivity failure.

### 3.3 Lifecycle E2E

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
