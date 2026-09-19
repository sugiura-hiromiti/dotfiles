# NixOS Impermanence Bootstrap Design

Date: 2026-09-18
Revised: 2026-09-19

## Purpose

Provide one same-system command for creating installation media for a declared
NixOS host:

```text
nix run .#build-installer -- --host HOST
```

The installer captures the current versioned dotfiles contents, generates
hardware facts on the target machine, installs one fixed
Disko/impermanence layout, and powers off for manual installer-media removal.

Cross-system installer builds, VCS history/ref semantics, and the existing
update workflow are out of scope.

## Source identity

Version control is used only to select which paths belong to dotfiles.

For this repository, `build-installer` uses JJ to enumerate the current
versioned path set. It copies the current filesystem contents of those paths
into a fresh staging directory outside the checkout, preserving relative paths,
symlinks, and executable bits. Commit IDs, parents, bookmarks, remotes, and
history do not participate in source identity.

The stage is added to the Nix store and becomes the immutable **base source**.
Ignored/unversioned files and generated artifacts in the checkout are outside
that source boundary.

The installer ISO carries that base source. At runtime it creates one writable
working tree:

```text
/run/dotfiles-installer/source
```

It restores owner-write permission, generates the host's `facter.json`, then
adds the complete tree to the local Nix store exactly once. The returned
**post-facter store path** is the transaction source identity.

Metadata evaluation, Disko realization, and `nixos-install --flake` all use
that exact post-facter store path. The writable working tree is not evaluated
again after the snapshot exists, and the store path remains rooted for the
transaction lifetime.

`build-installer` does not create an output link inside the checkout. It builds
with no out-link and reports the resulting installer output path.

## Lock graph

Source identity and dependency identity are separate invariants.

Every flake operation used by bootstrap construction or installer runtime uses
`--no-update-lock-file`. An incomplete or stale lock graph therefore fails
instead of being updated in memory or on disk.

Using `--no-write-lock-file` alone does not satisfy this contract.

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

Universal storage, facter, impermanence, authentication, Preservation, and boot
policy belongs to the constructed NixOS configuration; host profiles contain
host-specific policy only.

## Administrator, password, and boot contract

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

The installer service uses `UMask=0077`. The persistent password directory and
hash are owned by `root:root`; the directory is mode `0700` and the hash is
mode `0600`. The hash is written through a temporary file in the same
directory and atomically renamed to its final path.

The installed system uses:

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = false;
```

Those values are asserted after module merging. Boot uses the standard fallback
loader at `/EFI/BOOT/BOOT<ARCH>.EFI`.

## Preservation contract

The primary user's `dotfiles` directory is preserved under `/persist`.

Installer metadata includes the evaluated physical backing path for that
preserved directory. The installer treats this path as opaque policy from the
final NixOS configuration rather than reconstructing Preservation's path rules.

For the current layout this resolves to:

```text
/persist<evaluatedHome>/dotfiles
```

and while the installed system is mounted at `/mnt` the write destination is:

```text
/mnt/persist<evaluatedHome>/dotfiles
```

After boot, Preservation exposes the same data at:

```text
<evaluatedHome>/dotfiles
```

The persisted copy preserves executable bits, restores owner-write permission,
and is owned by the evaluated UID:GID.

## Installation transaction

Each service invocation starts with fresh installer-owned runtime state:

```text
sanitized immutable base source
→ writable facter workspace
→ immutable post-facter store snapshot
→ validate final metadata
→ realize Disko script
→ validate exactly one eligible target disk
→ create /dev/dotfiles-install-target
→ Disko provisions /mnt
→ atomically write root-only persistent password hash
→ nixos-install from the same post-facter store path
→ verify fallback EFI loader
→ copy dotfiles to the evaluated Preservation backing path
→ sync, unmount, power off
```

A fresh invocation may remove its own stale target symlink. Any unexpected
non-symlink object at that path is an error.

## Destructive barrier

No target-disk modification occurs before all four checks succeed against the
same post-facter source and frozen lock graph:

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

- **evaluation:** `nix flake check --no-build .`;
- **universal:** evaluation plus `checks.<system>.non-vm`, which builds every
  applicable non-VM check without requiring KVM;
- **lifecycle:** the impermanence VM and installer E2E on a builder advertising
  the `kvm` system feature.

Hosted non-KVM CI runs evaluation and universal checks only. The lifecycle gate
keeps its normal KVM requirement.

Focused non-VM tests cover:

- source staging includes modified versioned contents and excludes
  ignored/unversioned/generated paths;
- adding a prior build artifact in the checkout cannot change the staged base
  source identity;
- incomplete/stale lock graphs fail because every flake operation uses
  `--no-update-lock-file`;
- facter readiness/path consistency and single post-facter source identity;
- root-device cardinality (0/1/2 matches);
- destructive-barrier failures including Disko realization failure;
- secure password ownership/mode and retry behavior; and
- fixed storage and generated-CI behavior.

The lifecycle E2E boots the actual ISO with one blank eligible disk, installs
without public Internet/DNS/default route, verifies the password hash backing
file before unmount, boots the installed disk without the ISO, verifies
password/sudo and password-file ownership/mode again, verifies writable dotfiles
at the user's home, then verifies that data survives root reset and reboot.
