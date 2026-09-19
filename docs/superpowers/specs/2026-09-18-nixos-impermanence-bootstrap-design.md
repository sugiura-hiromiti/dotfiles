# NixOS Impermanence Bootstrap Design

Date: 2026-09-18
Revised: 2026-09-19

## Purpose

Provide one same-system command for creating installation media for a declared
NixOS host:

```text
nix run path:.#build-installer -- --host HOST
```

The installer captures the current dotfiles snapshot, generates hardware facts
on the target machine, installs one fixed Disko/impermanence layout, and powers
off for manual installer-media removal.

Cross-system installer builds and the existing update workflow are out of scope.

## Source identity

`path:.` defines the input snapshot used to build installer media. Nix stores
that snapshot immutably and the ISO carries it as the base source.

At runtime the installer creates one writable working tree:

```text
/run/dotfiles-installer/source
```

It restores owner-write permission, generates the host's `facter.json`, then
adds the complete tree to the local Nix store exactly once. The returned
**post-facter store path** is the transaction source identity.

Metadata evaluation, Disko realization, and `nixos-install --flake` all use
that exact store path. The writable working tree is not evaluated again after
the store snapshot exists. The store path remains rooted for the transaction
lifetime.

Installer-side Nix operations do not update the lock file. Repository-evaluating
bootstrap and generated-CI commands use explicit `path:...` flake references
so they use filesystem-snapshot semantics.

## Hosts, targets, and facter readiness

`host` is the host-registry key; `hostName` is the hostname configured inside
the operating system.

Installer packages exist for declared NixOS hosts whose `system` matches the
current `perSystem` system. The installer uses the host's declared default
runtime target; target naming and default-selection semantics belong to the
target model.

A declared host may build installer media before its facter report exists.
Final `nixosConfigurations` exist only for facter-ready hosts.

The repository has one canonical host/facter-path contract. Host discovery,
readiness, `hardware.facter.reportPath`, and installer facter placement derive
from it. Configurations, checks, and CI consume one shared set of facter-ready
NixOS target entries.

## Installed system

Disko owns one fixed layout:

```text
GPT
├── ESP               -> /boot
└── dotfiles-system   -> Btrfs
    ├── @root         -> /
    ├── @nix          -> /nix
    └── @persist      -> /persist
```

During installation the selected disk is exposed to Disko as:

```text
/dev/dotfiles-install-target
```

Storage device, partition label, and subvolume names are internal constants, not
host configuration.

Impermanence resets only `@root`. Initrd requires exactly one
`PARTLABEL=dotfiles-system` device, recreates `@root`, and leaves `@nix` and
`@persist` intact. The root-reset service carries the executables it invokes in
its own initrd service environment.

Universal storage, facter, impermanence, authentication, and boot policy belongs
to the constructed NixOS configuration; host profiles contain host-specific
policy only.

## Administrator and boot contract

The final configuration uses immutable password state:

```nix
users.mutableUsers = false;
users.users.<primary>.hashedPasswordFile =
  "/persist/etc/dotfiles/password-<primary>.hash";
```

Before destructive work the installer validates the effective primary account:

- absolute, normalized, non-root home without `..` traversal;
- integer UID and primary-group GID;
- non-empty primary group;
- the exact persistent password path;
- `isNormalUser == true`;
- membership in `wheel`; and
- effective sudo enabled.

The installed system uses:

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = false;
```

Those values are asserted after module merging. Boot uses the standard fallback
loader at `/EFI/BOOT/BOOT<ARCH>.EFI`.

## Installation transaction

Each service invocation starts with fresh installer-owned runtime state:

```text
base store snapshot
→ writable working tree
→ password hash + facter
→ immutable post-facter store snapshot
→ validate final metadata
→ realize Disko script
→ validate exactly one eligible target disk
→ create /dev/dotfiles-install-target
→ Disko provisions /mnt
→ write persistent password hash
→ nixos-install from the same post-facter store path
→ verify fallback EFI loader
→ persist a writable copy of dotfiles for the primary user
→ sync, unmount, power off
```

The persisted dotfiles copy preserves executable bits, restores owner-write
permission, and is owned by the evaluated UID:GID.

A fresh invocation may remove its own stale target symlink. Any unexpected
non-symlink object at that path is an error.

## Destructive barrier

No target-disk modification occurs before all four checks succeed against the
same post-facter source:

1. final metadata evaluation;
2. administrator and boot-policy validation;
3. Disko-script realization; and
4. target-disk validation.

An eligible target is a whole disk for which `lsblk` reports
`TYPE=disk`, `RM=false`, and `HOTPLUG=false`. Exactly one must exist.

This predicate is an eligibility filter, not proof of physical attachment. The
supported environment is responsible for making the intended installation disk
the sole eligible disk.

The barrier does not pre-realize the complete `system.build.toplevel`, so
install-time dependency, capacity, system-build, or bootloader failures may
still occur after Disko modifies the target.

Failures before Disko are retry-safe: restarting the service recreates runtime
state from the base snapshot and derives a fresh post-facter snapshot.

## Installer environment

The installer owns tty1 while interactive; tty2 remains available for
diagnostics. It starts after and wants `network-online.target`.

The real installer may require network access for locked content not already
available locally. The ISO enables the Nix CLI features required by its runtime
flake commands.

Supported installation assumes UEFI fallback-loader support, exactly one
intended eligible target disk, no second attached installed disk using
`PARTLABEL=dotfiles-system`, and installer media that is not itself eligible.

## Verification

Verification has three layers:

- **evaluation:** `nix flake check --no-build path:.`;
- **universal:** evaluation plus `checks.<system>.non-vm`, which builds every
  applicable non-VM check without requiring KVM;
- **lifecycle:** the impermanence VM and installer E2E on a builder advertising
  the `kvm` system feature.

Hosted non-KVM CI runs evaluation and universal checks only. The lifecycle gate
keeps its normal KVM requirement.

The lifecycle E2E is hermetic: it boots the actual ISO with one blank eligible
disk, installs without public Internet/DNS/default route, boots the installed
disk without the ISO, verifies password/sudo and writable persisted dotfiles,
then verifies root reset and persistent state across reboot.

Focused non-VM tests cover facter readiness/path consistency, root-device
cardinality (0/1/2 matches), post-facter source identity, destructive-barrier
failures including Disko realization failure, retry behavior, fixed storage,
and generated-CI source semantics.
