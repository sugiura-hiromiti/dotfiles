# Full-machine NixOS VM test design

## Goal

Test the real NixOS machine configuration in a QEMU-backed NixOS test without reconstructing the machine by hand.

The test must reuse the same logical `nixosConfiguration` graph used for the real `aarch64-linux-a` target, including resolved OS/system/host/variant profiles and ordinary NixOS modules. The VM layer may replace only configuration that is inherently tied to the real machine's hardware or storage topology.

This gives the repository one source of truth for the machine configuration while still making it bootable under QEMU.

## Current state

The current Preservation test creates a synthetic machine from a small hand-written module list. It verifies generic persistence semantics but does not prove that the real host configuration boots under test or that Preservation reacts correctly to services enabled by the real profile.

The real `aarch64-linux-a` host imports a generated hardware configuration containing real disk UUIDs, `/boot`, swap, and Parallels guest support. Those values cannot be used unchanged in a QEMU test VM.

## Design

### 1. Reuse the real evaluated machine configuration

The test should start from an existing entry in `self.nixosConfigurations`, for example:

`aarch64-linux-a--theme-light--session-gui`

The VM variant should be produced by extending that configuration rather than rebuilding the profile list separately.

The test therefore inherits automatically:

- users and groups;
- packages;
- networking and remote-access services;
- Bluetooth and power services;
- desktop/session configuration;
- Preservation;
- variants;
- theme/session selection;
- systemd units and other ordinary NixOS settings.

Any future change to the real target is therefore also present in the integration test unless the VM adaptation explicitly overrides it.

### 2. Add a minimal VM adaptation module

The test-only module owns the hardware boundary. It may override or disable only settings that cannot describe the QEMU guest.

Initial responsibilities:

- replace the real root filesystem with the test VM root;
- replace or disable the real `/boot` filesystem;
- remove the real swap device;
- disable Parallels guest integration;
- provide a dedicated persistent test disk mounted at `/persist`;
- apply any QEMU-test settings required by the NixOS test driver.

The module must not duplicate service, user, package, desktop, or Preservation configuration from the real host.

If another host-specific option later prevents QEMU boot, it should be added to this adaptation module only when the failure demonstrates that it is hardware/environment specific.

### 3. Keep the small Preservation test

The existing synthetic Preservation test remains useful as a focused module-contract test. It should stay small and fast.

The full-machine test is a separate integration test with a different responsibility:

- focused test: "does the Preservation module implement basic persistence semantics?"
- full-machine test: "does the actual machine configuration boot and preserve the state required by the services it really enables?"

This separation avoids making every low-level Preservation change depend solely on a large integration test.

### 4. Service-aware assertions come from the real profile

The full-machine test must not manually enable Tailscale, OpenSSH, Bluetooth, or power-profiles-daemon just for test coverage. Those services should be present because the real profile enables them.

The test should assert the resulting Preservation contract for services that are actually enabled by the machine configuration. Initial assertions should cover:

- `/var/lib/tailscale` when Tailscale is enabled;
- `/var/lib/bluetooth` when Bluetooth is enabled;
- `/var/lib/power-profiles-daemon` when power-profiles-daemon is enabled;
- configured OpenSSH host-key files when OpenSSH is enabled;
- `/var/lib/nixos` and `/etc/machine-id` as unconditional Preservation state.

Where a service can be exercised safely in the VM, prefer a semantic assertion over only checking mount topology. For example, OpenSSH host-key identity can be compared across reboot.

### 5. Persistence semantics

The VM should use a dedicated `/persist` disk and an ephemeral root suitable for reboot testing.

The test sequence should verify both sides of the lifetime contract:

1. boot the real machine variant;
2. write known data to a preserved path;
3. write known data to an unpreserved path;
4. capture service state that should retain identity across reboot;
5. reboot;
6. verify preserved state still exists;
7. verify unpreserved state is gone;
8. verify selected service identity/state is unchanged.

This keeps the central invariant explicit: only declared persistent state survives.

## Repository shape

Expected additions/changes:

- `nix/tests/nixos/preservation.nix`
  - remains the focused Preservation test;
- a new full-machine integration test under `nix/tests/nixos/`;
- a small test-only VM adaptation module under the test tree, or inline if it remains trivial;
- `nix/checks.nix`
  - exposes the new integration test as a Linux check;
- `flake.nix`
  - passes `self` or another suitable reference into the test/check code so the existing `nixosConfiguration` can be reused rather than reconstructed.

Exact filenames are implementation details; the architectural constraint is that the test imports/extents the existing target rather than reproducing its profile-resolution logic.

## Failure policy

The full-machine test should fail when:

- the real NixOS configuration no longer boots under its QEMU adaptation;
- a hardware-specific setting leaks past the adaptation layer and prevents boot;
- a service enabled by the real profile expects persistent state that the Preservation policy no longer preserves;
- declared persistent state disappears after reboot;
- undeclared ephemeral state unexpectedly survives.

It should not try to emulate physical Bluetooth radio behavior, Parallels-specific devices, GPU acceleration, or other hardware behavior that QEMU cannot meaningfully reproduce. Those belong outside this test's contract.

## Trade-offs

### Benefits

- one source of truth for the real machine and its integration test;
- catches profile composition failures that the current synthetic test cannot;
- automatically tracks services enabled or disabled by the real profile;
- makes Preservation policy regressions visible in the context where they matter;
- creates a reusable foundation for later bootstrapping and whole-machine tests.

### Costs

- slower and heavier than the focused Preservation test;
- requires explicit hardware/storage overrides;
- some real-machine features cannot be semantically tested in QEMU and must only be configuration-checked or disabled at the hardware boundary.

## Non-goals

- reproducing Parallels hardware exactly;
- testing physical Bluetooth devices;
- testing GPU/display performance;
- replacing the focused Preservation module test;
- duplicating the target/profile resolution logic inside the test.

## Acceptance criteria

The design is implemented when:

1. a NixOS test boots a VM derived from the real `aarch64-linux-a` NixOS target;
2. the test does not manually reconstruct that target's profile/module list;
3. only hardware/storage-specific configuration is overridden for QEMU;
4. service-aware Preservation assertions are driven by services enabled in the real target;
5. preserved and ephemeral state are both verified across reboot;
6. the focused Preservation test remains available separately;
7. the new integration test is part of `nix flake check` on Linux.
