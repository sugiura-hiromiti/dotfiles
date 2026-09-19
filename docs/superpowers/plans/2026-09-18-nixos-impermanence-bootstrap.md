# NixOS Impermanence Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans. Steps use checkbox syntax for tracking.

**Goal:** Implement the bootstrap design in
`docs/superpowers/specs/2026-09-18-nixos-impermanence-bootstrap-design.md`
without introducing a second storage, hardware, account, or source model.

**Source of truth:** The design spec owns behavioral and safety invariants. This
plan names implementation work and tests; it does not restate every invariant.

**Verification gates:**

- evaluation: `nix flake check --no-build path:.`;
- universal: evaluation plus `nix build -L path:.#checks.<system>.non-vm`;
- lifecycle: normal KVM-backed NixOS VM tests, including the impermanence VM and
  installer E2E.

---

## Task 1: Normalize the final NixOS model

**Files**

- Create: `nix/modules/nixos/features/storage/layout.nix`
- Modify: `nix/modules/nixos/features/storage/provisioning.nix`
- Delete: `nix/modules/nixos/features/storage/default.nix`
- Modify: `nix/modules/nixos/features/impermanence/{ephemeral-root,impermanence}.nix`
- Modify: `nix/configurations/nixos.nix`
- Modify: `nix/modules/nixos/default.nix`
- Modify: `nix/profiles/hosts/aarch64-linux-a/nixos.nix`
- Modify: `nix/lib/{hosts,targets}.nix`
- Modify: `nix/flake/{default,configurations,checks,ci}.nix`
- Modify: `nix/ci/default.nix`
- Modify: `nix/checks.nix`
- Modify: `nix/tests/nixos/{storage-provisioning,impermanence,impermanence-vm}.nix`
- Delete: `nix/tests/nixos/{ephemeral-root,storage-provisioning-vm}.nix`

### Step 1: Fix storage and root reset

- [ ] Add one internal storage-layout value containing the fixed partition label,
  subvolume names, and installer disk alias from the spec.
- [ ] Rewrite Disko provisioning to consume those constants directly; remove
  the public storage-option layer.
- [ ] Make the root-reset implementation internal to impermanence; remove its
  public `ephemeralRoot` configuration surface.
- [ ] Give the initrd root-reset service an explicit service-local `path`
  containing the executables it invokes, including `util-linux` and
  `btrfs-progs`.

Update the structural tests to prove the fixed Disko layout and initrd execution
environment. Factor the root-device selection/cardinality logic into a focused
testable component and cover 0, 1, and 2 `PARTLABEL=dotfiles-system` matches;
only the single-match case may proceed to root-subvolume mutation.

Do not keep a second VM solely for storage provisioning.

### Step 2: Centralize final-system policy

- [ ] Move universal facter, Disko, preservation, impermanence, authentication,
  and installer-compatible boot policy into `configurations/nixos.nix`.
- [ ] Final configurations set the canonical `hardware.facter.reportPath`,
  enable immutable users, and set the primary account's persistent password
  path.
- [ ] Assert the effective administrator and bootloader contract after all
  modules merge.
- [ ] Remove filesystem, swap, facter-path, and other universal bootstrap policy
  from the production host profile.

The host profile should contain only host-specific policy.

### Step 3: Model facter readiness once

The host registry owns one repository-relative host-directory value and derives
both absolute and relative facter paths from it.

- [ ] Change `lib/hosts.nix` to export the canonical facter-path helpers.
- [ ] In `flake/default.nix`, derive NixOS target sets once:

```nix
declaredNixosTargetEntries = targets.mkTargetConfigEntries "nixos";
readyNixosTargetEntries = lib.filter (
  entry: builtins.pathExists (facterPathForHost entry.config.host)
) declaredNixosTargetEntries;

nixosTargetSets = {
  declared = declaredNixosTargetEntries;
  ready = readyNixosTargetEntries;
};
```

The important property is one declared set and one facter-ready set.

- [ ] Add a generic `mkTargetConfigsFromEntries` helper to `lib/targets.nix`.
  Keep `mkTargetConfigs` as the wrapper for callers that want all entries.
- [ ] Export `nixosConfigurations` from the ready set only.
- [ ] Feed that same ready set to NixOS checks and CI. Those consumers must not
  recompute facter readiness.
- [ ] Keep Home Manager and Darwin target discovery unchanged.

A declared host without facter is a valid bootstrap state: installer packages
still exist, while final NixOS configuration/check/CI references do not.

### Step 4: Put default-target semantics back in the target model

The bootstrap code should consume host defaults, not own generic target-name
semantics.

- [ ] Move/default any reusable "select the declared default target for this
  host" helper and its ordering-independence regression into the target-model
  tests/implementation.
- [ ] CI consumes that helper/result.
- [ ] When no facter-ready representative NixOS target exists, CI remains
  structurally valid and omits only the NixOS-specific evaluation/build work.
- [ ] Generated CI commands that evaluate this repository use explicit
  `path:.` flake references, preserving the source contract.

Do not add bootstrap-specific tests for generic theme/session list ordering after
the target model itself proves the property.

### Step 5: Keep one behavioral impermanence VM

- [ ] `impermanence-vm.nix` proves:

```text
fixed layout
→ boot
→ create disposable + persistent markers
→ reboot
→ disposable marker gone
→ persistent marker survives
→ @root exists
```

- [ ] Delete the standalone `ephemeral-root.nix` and
  `storage-provisioning-vm.nix` tests.

### Step 6: Add focused readiness regressions

Add evaluation tests proving:

- [ ] declared-without-facter hosts remain valid bootstrap inputs;
- [ ] ready targets use exactly the canonical facter path;
- [ ] configurations, NixOS checks, and CI all consume the same ready target set;
- [ ] generated CI contains no repository-evaluating Git-flake shorthand where
  the source contract requires explicit `path:.`; this text-level regression is
  intentional because the spelling selects different Nix source semantics;
- [ ] moving the canonical host-directory root changes absolute and installer
  relative facter destinations consistently; and
- [ ] effective administrator/bootloader values satisfy the spec.

Prefer testing these domain properties over searching generated text for a
specific implementation spelling.

### Step 7: Define the real non-VM gate and CI split

- [ ] Split check construction into non-VM and VM-backed sets.
- [ ] Expose `checks.<system>.non-vm` as an aggregate derivation whose
  dependencies force every applicable non-VM check for that system to build.
  Do not include the aggregate itself in its dependency set.
- [ ] Keep VM-backed checks as ordinary checks with their normal KVM
  requirements.
- [ ] Change generated Linux CI on `ubuntu-24.04-arm` so it runs:
  1. `nix flake check --no-build path:.`; then
  2. `nix build -L path:.#checks.aarch64-linux.non-vm`.
- [ ] Remove unrestricted hosted-ARM `nix flake check` from generated
  `full-build.yml` while VM-backed checks remain part of `checks`.
- [ ] Run lifecycle checks only on a builder advertising `kvm`. If no such CI
  runner is configured, keep the lifecycle gate explicit/manual rather than
  weakening or silently skipping its requirements.
- [ ] Keep generated repository-evaluating CI commands on explicit `path:.`
  flake references.

### Step 8: Verify

```bash
nix flake check --no-build path:.
nix build -L   path:.#checks.$(nix eval --raw --impure --expr builtins.currentSystem).non-vm
```

Run the impermanence VM separately on a KVM-capable builder.

Commit this task as one coherent final-system/readiness/verification refactor.

---

## Task 2: Implement the installer transaction

**Files**

- Create: `nix/installer/install.nu`
- Create: `nix/installer/script.nix`
- Create: `nix/tests/installer/runtime.nix`
- Modify: `nix/checks.nix`

The writable working tree is `/run/dotfiles-installer/source`. After facter
generation it is added to the local Nix store exactly once; the resulting
post-facter store path becomes the transaction source identity. The Disko alias
is `/dev/dotfiles-install-target`.

### Step 1: Package one installer script

- [ ] `script.nix` supplies the runtime script with the declared host, final
  target, primary account, immutable source path, canonical relative facter
  path, and EFI architecture.
- [ ] The runtime script does not reconstruct repository-relative host paths.
- [ ] Package the runtime dependencies needed by the transaction.

### Step 2: Implement fresh reversible preparation

Each invocation:

- [ ] safely clears only installer-owned stale runtime state and a stale
  installer-created target symlink;
- [ ] copies the immutable source to the writable working tree;
- [ ] restores owner-write permission on the working tree while preserving
  executable bits;
- [ ] prompts twice for a matching non-empty password and hashes it with
  yescrypt;
- [ ] writes fresh facter data at the canonical relative facter path;
- [ ] adds the complete post-facter tree to the local Nix store exactly once;
- [ ] records that store path and keeps it rooted for the transaction lifetime;
  and
- [ ] never uses the writable working tree as the final source identity after
  the store snapshot exists.

An unexpected non-symlink object at the target-alias path aborts the transaction.

### Step 3: Evaluate and validate final metadata

- [ ] Evaluate only the final metadata needed by the installer from the exact
  post-facter store path.
- [ ] Validate the administrator and bootloader contract defined in the spec.
- [ ] Realize only the Disko script from that same store path before the
  destructive barrier.
- [ ] Carry the same store path into `nixos-install --flake`; do not resnapshot
  `/run/dotfiles-installer/source` between validation and installation.

All installer-side Nix operations use `--no-update-lock-file`.

### Step 4: Implement the destructive barrier

- [ ] Read `lsblk --json --output PATH,TYPE,RM,HOTPLUG`.
- [ ] Require exactly one eligible target disk according to the spec.
- [ ] Only then create `/dev/dotfiles-install-target` and run Disko.

No target-disk write occurs before this point.

### Step 5: Install and persist

After Disko:

- [ ] require the expected mountpoints;
- [ ] write the password hash to the evaluated persistent password path with
  restrictive permissions;
- [ ] run `nixos-install` against the same post-facter store path;
- [ ] require the architecture-specific fallback EFI loader;
- [ ] copy the post-facter source tree to the evaluated user's persistent home;
- [ ] restore owner-write permission on that persisted tree while preserving
  executable bits, then chown it to the evaluated UID:GID;
- [ ] sync, unmount, verify unmounted, and power off.

Errors exit non-zero. The pre-Disko retry guarantee does not extend to failures
after Disko.

### Step 6: Test transaction behavior

Use fake external commands for fast runtime tests. Cover the behavioral
boundaries:

- [ ] every invocation recreates runtime source from the immutable base;
- [ ] facter is written at the supplied canonical relative destination;
- [ ] exactly one post-facter store snapshot is created and its returned path is
  used by final evaluation, Disko realization, and installation;
- [ ] modifying the writable working tree after the store snapshot is created
  does not change what later validation/installation observes;
- [ ] invalid administrator metadata fails before Disko;
- [ ] Disko-script realization failure leaves the target alias absent, never
  invokes Disko/nixos-install/target mutation, and a retry starts cleanly;
- [ ] zero or multiple eligible target disks fail before Disko;
- [ ] one eligible target disk creates the alias;
- [ ] an unexpected alias-path object fails safely;
- [ ] a pre-Disko failed run followed by a retry starts from clean transaction
  state;
- [ ] lock mutation is never requested.

Do not add fake-command assertions whose only purpose is to preserve a particular
command-line spelling when the behavioral property is already covered.

### Step 7: Verify

```bash
nix build -L   path:.#checks.$(nix eval --raw --impure --expr builtins.currentSystem).installer-runtime
nix flake check --no-build path:.
nix build -L   path:.#checks.$(nix eval --raw --impure --expr builtins.currentSystem).non-vm
```

Commit the installer transaction separately from ISO/E2E work.

---

## Task 3: Add installer packages, ISO, and lifecycle E2E

**Files**

- Create: `nix/installer/iso.nix`
- Create: `nix/flake/installer.nix`
- Create: `nix/apps/build-installer/{default.nix,build.nu,tests/run.sh}`
- Create: `nix/tests/installer/e2e.nix`
- Create: `nix/apps/test-installer-e2e/default.nix`
- Modify: `nix/flake/{apps,default}.nix`
- Modify: `nix/checks.nix`
- Modify: `README.org`, `flake.nix`

### Step 1: Generate same-system installer packages

- [ ] For each declared same-system NixOS host, derive the installer target from
  the target model's declared default runtime target.
- [ ] Construct `packages.installer-<host>` from the immutable
  `self.outPath`, canonical relative facter path, installer script, and ISO
  configuration.
- [ ] Do not require the final NixOS configuration to exist while constructing
  an installer package.

Add the bootstrap regression here: a declared same-system host without facter
still produces its installer package.

### Step 2: Keep `build-installer` thin

`build-installer` is an ergonomic wrapper, not a second source model.

- [ ] It accepts `--host HOST`.
- [ ] It builds `installer-HOST` from the immutable source already captured by
  the app evaluation.
- [ ] It uses a flat `result-installer-HOST` out-link.
- [ ] Invalid/non-same-system hosts fail because the package does not exist.

The source contract itself is tested by installer behavior and package
construction; do not multiply string-level assertions solely to prove that the
wrapper is thin.

### Step 3: Build the specialized ISO

- [ ] Import the minimal installation CD module.
- [ ] Enable the Nix CLI features required by runtime flake commands.
- [ ] Reserve tty1 for `dotfiles-installer.service`; keep tty2 diagnostic.
- [ ] Start the installer after/wanting `network-online.target`.
- [ ] Give the service the runtime package set and execute the packaged installer
  script.

Add small evaluation checks for the ISO properties that materially affect
runtime behavior.

A pre-Disko fetch/connectivity failure should print a concrete recovery
instruction to repair networking on tty2 and restart the service.

### Step 4: Add the lifecycle E2E

Use `pkgs.testers.runNixOSTest` with UEFI, the actual installer ISO, and one
blank eligible target disk.

Expose the interactive driver package and a `test-installer-e2e` app.

The E2E is offline/hermetic. Supply required flake inputs and install-time store
content through declared test dependencies or resources reachable only inside
the isolated test network.

Verify the complete lifecycle:

```text
boot actual ISO
→ installer owns tty1; tty2 remains usable
→ password + facter transaction completes
→ fixed Disko layout installed
→ fallback EFI loader exists
→ installer powers off
→ boot installed disk without ISO
→ password login + sudo work
→ primary user modifies a normal file in persisted dotfiles successfully
→ create disposable + persistent data
→ reboot
→ disposable data gone
→ persistent data and writable dotfiles survive
```

Connectivity-failure/retry behavior remains a runtime-test concern, not a public
Internet dependency of this E2E.

### Step 5: Documentation and final verification

Document only the operator workflow:

```text
edit dotfiles
→ nix run path:.#build-installer -- --host HOST
→ write/attach ISO
→ boot and enter password
→ poweroff
→ remove media
→ boot installed system
```

Run the evaluation + universal gates:

```bash
nix flake check --no-build path:.
nix build -L   path:.#checks.$(nix eval --raw --impure --expr builtins.currentSystem).non-vm
nix run path:.#build-installer -- --host aarch64-linux-a
test -e result-installer-aarch64-linux-a
```

On a KVM-capable builder, run the lifecycle gate:

```bash
nix flake check -L path:.
nix run path:.#test-installer-e2e
```

Commit the ISO/builder/E2E work as one coherent task.

---

## Scope discipline

While implementing this plan:

- keep safety/behavior contracts in the design spec rather than duplicating them
  in every task;
- keep generic target naming/default-selection behavior in the target model;
- keep CI rendering mechanics in CI code/tests;
- keep installer runtime tests focused on transaction boundaries;
- keep one structural layer for fixed storage and one behavioral impermanence VM;
- do not add configuration surfaces for values intentionally fixed by the
  bootstrap design; and
- do not boot the generated ISO on the real machine as part of this plan.
