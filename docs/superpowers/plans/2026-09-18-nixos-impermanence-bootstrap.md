# NixOS Impermanence Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans. Steps use checkbox syntax for tracking.

**Goal:** Implement
`docs/superpowers/specs/2026-09-18-nixos-impermanence-bootstrap-design.md`.
The spec owns behavioral/safety contracts; this plan owns implementation order
and tests.

## Verification commands

```bash
# Evaluation only
nix flake check --no-build path:.

# All non-VM checks
nix build -L   path:.#checks.$(nix eval --raw --impure --expr builtins.currentSystem).non-vm

# Lifecycle, on a KVM-capable builder
nix flake check -L path:.
nix run path:.#test-installer-e2e
```

---

## Task 1: Final NixOS model, readiness, and non-VM verification

**Files**

- Create: `nix/modules/nixos/features/storage/layout.nix`
- Modify: `nix/modules/nixos/features/storage/provisioning.nix`
- Modify: `nix/modules/nixos/features/impermanence/{ephemeral-root,impermanence}.nix`
- Modify: `nix/configurations/nixos.nix`
- Modify: `nix/modules/nixos/default.nix`
- Modify: `nix/profiles/hosts/aarch64-linux-a/nixos.nix`
- Modify: `nix/lib/{hosts,targets}.nix`
- Modify: `nix/flake/{default,configurations,checks,ci}.nix`
- Modify: `nix/ci/default.nix`
- Modify: `nix/checks.nix`
- Modify: `nix/tests/nixos/{storage-provisioning,impermanence,impermanence-vm}.nix`
- Delete: `nix/modules/nixos/features/storage/default.nix`
- Delete: `nix/tests/nixos/{ephemeral-root,storage-provisioning-vm}.nix`

### 1.1 Fix storage and root reset

- [ ] Define the fixed partition label, subvolumes, and installer disk alias once
  in `storage/layout.nix`.
- [ ] Make Disko provisioning consume those values directly.
- [ ] Internalize root reset under impermanence and remove the public
  `ephemeralRoot` configuration surface.
- [ ] Give the initrd reset service a service-local environment containing the
  tools it executes, including `util-linux` and `btrfs-progs`.
- [ ] Factor root-device selection into a focused testable component: 0 and 2
  matching `PARTLABEL=dotfiles-system` devices fail; exactly 1 succeeds.
- [ ] Keep one behavioral impermanence VM proving `@root` reset while
  `@persist` survives reboot.

### 1.2 Centralize final-system policy

- [ ] Construct universal facter, storage, preservation, impermanence,
  authentication, and boot policy in `configurations/nixos.nix`.
- [ ] Set the canonical `hardware.facter.reportPath`.
- [ ] Set immutable users and the primary account's persistent password path.
- [ ] Assert the effective administrator and bootloader contract after module
  merging.
- [ ] Leave production host profiles with host-specific policy only.

### 1.3 Model facter readiness once

- [ ] Make the host registry own the canonical host-directory/facter-path
  helpers.
- [ ] Derive two NixOS target sets once in `flake/default.nix`: all declared
  targets and the facter-ready subset.
- [ ] Add a generic way to construct target configurations from supplied entries.
- [ ] Export `nixosConfigurations` from the ready set.
- [ ] Feed that same ready set to NixOS checks and CI.
- [ ] Keep installer-package discovery based on declared same-system NixOS
  hosts, so a facter-less host remains bootstrappable.
- [ ] Keep default-target selection in the target model and reuse it from
  installer/CI consumers.

Focused evaluation tests prove declared-vs-ready behavior, facter-path
consistency, effective administrator/boot values, and default-target selection.

### 1.4 Define non-VM verification

- [ ] Classify checks once as non-VM or VM-backed.
- [ ] Expose `checks.<system>.non-vm` as an aggregate that builds every
  applicable non-VM check.
- [ ] Keep VM tests as ordinary KVM-requiring checks.
- [ ] Make generated hosted Linux CI run the evaluation gate and the non-VM
  aggregate instead of building VM checks.
- [ ] Keep lifecycle tests for a KVM-capable builder.
- [ ] Keep repository-evaluating generated CI commands on explicit `path:.`
  flake references.

Run the evaluation and universal commands from **Verification commands** before
committing this task.

---

## Task 2: Installer transaction

**Files**

- Create: `nix/installer/install.nu`
- Create: `nix/installer/script.nix`
- Create: `nix/tests/installer/runtime.nix`
- Modify: `nix/checks.nix`

### 2.1 Package the runtime

- [ ] Package one installer script with the declared host, default target,
  primary account, immutable base source, canonical relative facter path, and
  EFI architecture.
- [ ] Include the runtime tools required by the transaction.

### 2.2 Prepare one post-facter source identity

Each invocation:

- [ ] clears installer-owned stale runtime state safely;
- [ ] recreates `/run/dotfiles-installer/source` from the immutable base;
- [ ] restores owner-write permission while preserving executable bits;
- [ ] prompts twice for a matching non-empty password and hashes it with
  yescrypt;
- [ ] generates facter at the canonical relative path;
- [ ] adds the complete tree to the local Nix store once; and
- [ ] records and roots the returned post-facter store path.

From this point onward metadata evaluation, Disko realization, and installation
all use that store path.

### 2.3 Validate before destruction

- [ ] Evaluate only the administrator/boot metadata required by the installer.
- [ ] Validate it against the spec.
- [ ] Realize the Disko script from the same store path.
- [ ] Read `lsblk --json --output PATH,TYPE,RM,HOTPLUG` and require exactly one
  eligible disk.
- [ ] Create `/dev/dotfiles-install-target` only after all previous steps
  succeed.

A stale installer-created alias symlink may be replaced; any unexpected
non-symlink object at that path is an error.

### 2.4 Install and persist

After the destructive barrier:

- [ ] run Disko and require the expected mountpoints;
- [ ] write the password hash to the evaluated persistent path;
- [ ] run `nixos-install --flake` from the post-facter store path with no lock
  update;
- [ ] verify the fallback EFI loader;
- [ ] copy the post-facter source to the primary user's persistent home;
- [ ] restore owner-write permission while preserving executable bits and chown
  the tree to the evaluated UID:GID; and
- [ ] sync, unmount, and power off.

### 2.5 Runtime tests

Use fake external commands to prove:

- [ ] each invocation starts from a fresh working tree;
- [ ] facter lands at the canonical relative path;
- [ ] exactly one post-facter snapshot is created and reused by evaluation,
  Disko realization, and installation;
- [ ] later changes to the writable working tree cannot affect those operations;
- [ ] invalid administrator metadata fails before destructive work;
- [ ] Disko realization failure creates no target alias and invokes no
  destructive/install command;
- [ ] 0 or multiple eligible disks fail before Disko; exactly 1 proceeds;
- [ ] unexpected alias-path objects fail safely;
- [ ] a pre-Disko failure can be retried from clean runtime state; and
- [ ] installer Nix commands do not update the lock file.

Run the evaluation and universal commands from **Verification commands** before
committing this task.

---

## Task 3: Installer package, ISO, and lifecycle E2E

**Files**

- Create: `nix/installer/iso.nix`
- Create: `nix/flake/installer.nix`
- Create: `nix/apps/build-installer/{default.nix,build.nu,tests/run.sh}`
- Create: `nix/tests/installer/e2e.nix`
- Create: `nix/apps/test-installer-e2e/default.nix`
- Modify: `nix/flake/{apps,default}.nix`
- Modify: `nix/checks.nix`
- Modify: `README.org`, `flake.nix`

### 3.1 Generate same-system installer packages

- [ ] Create `packages.installer-<host>` for each declared same-system NixOS
  host from `self.outPath`, the target-model default target, canonical facter
  path, installer script, and ISO configuration.
- [ ] Prove that a declared host without facter still produces its installer
  package.

### 3.2 Keep `build-installer` as a thin CLI

- [ ] Accept `--host HOST`.
- [ ] Build the corresponding installer package from the source captured by app
  evaluation.
- [ ] Write `result-installer-HOST`.
- [ ] Reject hosts for which no same-system installer package exists.

### 3.3 Build the ISO

- [ ] Import the minimal installation CD module.
- [ ] Enable required Nix CLI features.
- [ ] Reserve tty1 for `dotfiles-installer.service`; keep tty2 for diagnostics.
- [ ] Start the service after/wanting `network-online.target`.
- [ ] Execute the packaged installer with its runtime dependencies.
- [ ] On pre-Disko connectivity failure, print a tty2 recovery/restart
  instruction.

### 3.4 Lifecycle E2E

Use `pkgs.testers.runNixOSTest` with UEFI, the actual installer ISO, and one
blank eligible target disk. Provide all install-time source/store dependencies
inside the hermetic test environment.

Verify:

```text
boot actual ISO
→ tty1 installer + usable tty2
→ facter/password transaction
→ fixed Disko layout
→ fallback EFI loader
→ poweroff
→ boot installed disk without ISO
→ password login + sudo
→ primary user can modify persisted dotfiles
→ create disposable + persistent markers
→ reboot
→ disposable marker gone; persistent marker and dotfiles survive
```

Expose `test-installer-e2e` for interactive execution.

### 3.5 Operator documentation

Document only:

```text
edit dotfiles
→ nix run path:.#build-installer -- --host HOST
→ write/attach ISO
→ boot and enter password
→ poweroff
→ remove media
→ boot installed system
```

Run all commands from **Verification commands** on the appropriate builders,
then commit the ISO/E2E task.
