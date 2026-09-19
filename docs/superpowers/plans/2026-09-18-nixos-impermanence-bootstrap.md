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
nix flake check --no-build .

# All non-VM checks
nix build -L   .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).non-vm

# Lifecycle, on a KVM-capable builder
nix flake check -L .
nix run .#test-installer-e2e
```

---

## Task 1: Final NixOS model, readiness, Preservation, and verification

**Files**

- Create: `nix/modules/nixos/features/storage/layout.nix`
- Modify: `nix/modules/nixos/features/storage/provisioning.nix`
- Modify: `nix/modules/nixos/features/impermanence/{ephemeral-root,impermanence,preservation}.nix`
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

### 1.2 Centralize final-system and Preservation policy

- [ ] Construct universal facter, storage, preservation, impermanence,
  authentication, and boot policy in `configurations/nixos.nix`.
- [ ] Set the canonical `hardware.facter.reportPath`.
- [ ] Set immutable users and the primary account's persistent password path.
- [ ] Preserve the primary user's `dotfiles` directory under `/persist`.
- [ ] Include the evaluated physical dotfiles backing path in installer
  metadata. Derive it on the Nix/configuration side from effective Preservation
  policy and the evaluated user home; the runtime installer treats it as opaque.
- [ ] Assert the effective administrator, Preservation, and bootloader contract
  after module merging.
- [ ] Leave production host profiles with host-specific policy only.

Evaluation tests prove that the current primary user resolves to a backing path
equivalent to `/persist<home>/dotfiles`.

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
- [ ] Keep default-target selection in the target model for installer-package
  selection.

### 1.4 Define non-VM verification

- [ ] Classify checks once as non-VM or VM-backed.
- [ ] Expose `checks.<system>.non-vm` as an aggregate that builds every
  applicable non-VM check.
- [ ] Keep VM tests as ordinary KVM-requiring checks.
- [ ] Make generated hosted Linux CI run the evaluation gate and the non-VM
  aggregate instead of VM checks or representative NixOS-target plumbing.
- [ ] Keep lifecycle tests for a KVM-capable builder.

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
- [ ] Require `--no-update-lock-file` on every installer-side flake command.

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

Metadata evaluation, Disko realization, and installation all use that exact
store path.

### 2.3 Validate before destruction

- [ ] Evaluate only the administrator, Preservation-backing, and boot metadata
  required by the installer.
- [ ] Validate it against the spec.
- [ ] Realize the Disko script from the same store path.
- [ ] Pass `--no-update-lock-file` to both operations.
- [ ] Read `lsblk --json --output PATH,TYPE,RM,HOTPLUG` and require exactly one
  eligible disk.
- [ ] Create `/dev/dotfiles-install-target` only after all previous steps
  succeed.

A stale installer-created alias symlink may be replaced; any unexpected
non-symlink object at that path is an error.

### 2.4 Install and persist securely

After the destructive barrier:

- [ ] run Disko and require the expected mountpoints;
- [ ] create `/mnt/persist/etc/dotfiles` as `root:root`, mode `0700`;
- [ ] write the yescrypt hash to a temporary file in that directory as
  `root:root`, mode `0600`, then atomically rename it to the evaluated
  password path;
- [ ] run `nixos-install --flake` from the post-facter store path with
  `--no-update-lock-file`;
- [ ] verify the fallback EFI loader;
- [ ] prepend `/mnt` to the evaluated Preservation backing path and copy the
  post-facter source there;
- [ ] restore owner-write permission while preserving executable bits and chown
  the persisted dotfiles tree to the evaluated UID:GID; and
- [ ] sync, unmount, and power off.

The systemd installer service created in Task 3 uses `UMask=0077`.

### 2.5 Runtime tests

Use fake external commands/fixtures to prove:

- [ ] each invocation starts from a fresh working tree;
- [ ] facter lands at the canonical relative path;
- [ ] exactly one post-facter snapshot is created and reused by evaluation,
  Disko realization, and installation;
- [ ] later changes to the writable working tree cannot affect those operations;
- [ ] every flake operation receives `--no-update-lock-file`;
- [ ] an intentionally incomplete/stale lock graph fails rather than resolving
  an updated graph;
- [ ] invalid administrator/Preservation metadata fails before destructive work;
- [ ] Disko realization failure creates no target alias and invokes no
  destructive/install command;
- [ ] 0 or multiple eligible disks fail before Disko; exactly 1 proceeds;
- [ ] unexpected alias-path objects fail safely; and
- [ ] a pre-Disko failure can be retried from clean runtime state.

Run the evaluation and universal commands from **Verification commands** before
committing this task.

---

## Task 3: Sanitized bootstrap source, installer package, ISO, and lifecycle E2E

**Files**

- Create: `nix/installer/iso.nix`
- Create: `nix/flake/installer.nix`
- Create: `nix/apps/build-installer/{default.nix,build.nu,tests/run.sh}`
- Create: `nix/tests/installer/e2e.nix`
- Create: `nix/apps/test-installer-e2e/default.nix`
- Modify: `nix/flake/{apps,default}.nix`
- Modify: `nix/checks.nix`
- Modify: `README.org`, `flake.nix`

### 3.1 Capture the sanitized base source

`build-installer` is responsible for the outer source boundary.

- [ ] Enumerate the current versioned path set with JJ; do not query commit IDs,
  parents, bookmarks, remotes, or history.
- [ ] Copy the current filesystem contents of those paths to a fresh staging
  directory outside the checkout, preserving paths, symlinks, and executable
  bits.
- [ ] Add the stage to the Nix store and record the resulting base store path.
- [ ] Evaluate/build the installer package from that sanitized base using
  `path:<base-store-path>#installer-HOST` with `--no-update-lock-file`.
- [ ] Do not use the `build-installer` app's own `self.outPath` as the
  installer base source.
- [ ] Build with `--no-link --print-out-paths`; do not create
  `result-installer-HOST` in the checkout.

Focused source tests prove:

- [ ] modified versioned file contents appear in the captured base;
- [ ] ignored/unversioned files such as a probe under `.ssh/` do not appear;
- [ ] an unversioned/generated `result-installer-*` symlink does not appear;
- [ ] adding ignored/unversioned/generated artifacts does not change the base
  store path; and
- [ ] executable bits and symlink targets survive staging.

### 3.2 Generate same-system installer packages

- [ ] Create `packages.installer-<host>` for each declared same-system NixOS
  host from the sanitized flake source's `self.outPath`, target-model default
  target, canonical facter path, installer script, and ISO configuration.
- [ ] Prove that a declared host without facter still produces its installer
  package.
- [ ] Reject hosts for which no same-system installer package exists.

### 3.3 Build the ISO

- [ ] Import the minimal installation CD module.
- [ ] Enable required Nix CLI features.
- [ ] Reserve tty1 for `dotfiles-installer.service`; keep tty2 for diagnostics.
- [ ] Start the service after/wanting `network-online.target`.
- [ ] Set `UMask=0077` on the installer service.
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
→ before unmount:
    password backing file is root:root 0600
    /mnt/persist<home>/dotfiles contains the captured source
→ fallback EFI loader
→ poweroff
→ boot installed disk without ISO
→ password login + sudo
→ password backing file remains root:root 0600
→ <home>/dotfiles exposes the preserved source and is user-writable
→ create disposable + persistent markers
→ reboot
→ disposable marker gone; preserved dotfiles/data survive
```

Expose `test-installer-e2e` for interactive execution.

### 3.5 Operator documentation

Document only:

```text
edit/version dotfiles
→ nix run .#build-installer -- --host HOST
→ use the reported installer store output
→ write/attach ISO
→ boot and enter password
→ poweroff
→ remove media
→ boot installed system
```

Run all commands from **Verification commands** on the appropriate builders,
then commit the source/ISO/E2E task.
