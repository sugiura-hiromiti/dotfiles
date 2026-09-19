# NixOS Impermanence Bootstrap Design

Date: 2026-09-18
Revised: 2026-09-19

## Purpose

Provide one same-system command for creating installation media for a declared
NixOS host:

```text
nix run path:.#build-installer -- --host HOST
```

The installer captures the current filesystem snapshot, generates hardware facts
on the target machine, installs one fixed Disko/impermanence layout, and powers
off for manual installer-media removal.

Cross-system installer builds and the existing update workflow are outside this
design.

## Source contract

`path:.` is the source boundary.

Nix snapshots the invocation tree into the store; that immutable store path is
the installer base source. The builder and ISO consume that source directly.

Each installer-service invocation creates one writable runtime copy at:

```text
/run/dotfiles-installer/source
```

It writes fresh `facter.json` into that copy. From that point onward the copy
is logically immutable. Final metadata evaluation, Disko realization, and
`nixos-install --flake` all evaluate that same tree with `path:` semantics.

Installer runtime code does not reconstruct, refetch, filter, or derive source
identity from Git state. Files present inside the source boundary, including
`.git` when present, are inert unless used by normal Nix evaluation.

Installer-side Nix operations use `--no-update-lock-file`.

## Host and target model

`host` means the host-registry key. `hostName` means the hostname configured
inside the operating system.

Installer packages exist for declared NixOS hosts whose `system` matches the
current `perSystem` system.

The installer selects the host's declared default runtime target:

```nix
targetNames.mkSystemTargetName {
  inherit (host) targetHost;
  inherit (host.runtime) targetAxes;
  themeName = host.runtime.defaultTheme;
  sessionName = host.runtime.defaultSession;
}
```

Target naming semantics belong to the target model; the installer only consumes
the resulting default target.

## Facter readiness

A declared host and an evaluable final NixOS target are different states.

A declared same-system NixOS host may build installer media before its
`facter.json` exists. Final `nixosConfigurations` are exported only when the
host's facter report exists.

The repository has one canonical host-directory/facter-path contract. Registry
discovery, readiness, `hardware.facter.reportPath`, and installer runtime
placement of fresh facter data derive from that contract.

Configurations, checks, and CI consume one shared set of facter-ready NixOS
target entries. They do not independently recompute readiness.

## Installed system

Disko owns one fixed storage layout:

```text
GPT
├── ESP               -> /boot
└── dotfiles-system   -> Btrfs
    ├── @root         -> /
    ├── @nix          -> /nix
    └── @persist      -> /persist
```

During installation Disko receives the selected disk through:

```text
/dev/dotfiles-install-target
```

There is no configurable storage-device, partition-label, or subvolume API in
this bootstrap design.

Impermanence resets only `@root`. During initrd it requires exactly one
partition with `PARTLABEL=dotfiles-system`, deletes the old `@root`, recreates
it, and keeps `/nix` and `/persist` available for boot.

The initrd root-reset service declares the executable dependencies it invokes,
including `util-linux` and `btrfs-progs`, in its own service environment.

Universal storage, facter, impermanence, and authentication policy belongs to
the constructed NixOS configuration. Host profiles contain only host-specific
policy.

## Administrator contract

The final NixOS configuration uses immutable password state:

```nix
users.mutableUsers = false;
users.users.<primary>.hashedPasswordFile =
  "/persist/etc/dotfiles/password-<primary>.hash";
```

Before destructive work, the installer evaluates the final configuration and
requires the primary account to have:

- an absolute, normalized, non-root home without `..` traversal;
- integer UID and primary-group GID;
- a non-empty primary group;
- the exact persistent password path above;
- `isNormalUser == true`;
- membership in `wheel`; and
- effective sudo enabled.

The installed bootloader contract is:

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = false;
```

Final configuration evaluation asserts those effective values after module
merging.

Boot relies on the standard fallback EFI loader:

```text
/EFI/BOOT/BOOT<ARCH>.EFI
```

## Installation transaction

Each installer-service invocation starts from fresh installer-owned runtime
state.

The transaction is:

```text
boot ISO
↓
recreate installer-owned runtime state
↓
copy immutable base source to /run/dotfiles-installer/source
↓
prompt twice and hash administrator password
↓
generate facter.json at the canonical host-relative path
↓
evaluate and validate final administrator/boot metadata
↓
realize the Disko script
↓
require exactly one eligible target disk
↓
/dev/dotfiles-install-target -> selected disk
↓
Disko provisions and mounts /mnt
↓
write the password hash under /mnt/persist
↓
nixos-install from the same runtime source
↓
verify fallback EFI loader
↓
persist the runtime dotfiles source under the primary user's home
↓
sync, unmount, power off
```

A stale installer-created target symlink may be removed when a fresh invocation
starts. An unexpected non-symlink object at that path is an error.

## Destructive barrier

No target-disk modification occurs until all of these have succeeded:

1. final metadata evaluation;
2. administrator and boot-policy validation;
3. Disko-script realization; and
4. target-disk validation.

An eligible target is exactly one whole disk for which `lsblk` reports:

```text
type == "disk"
rm == false
hotplug == false
```

This predicate is an eligibility filter, not proof of physical attachment. The
supported environment must ensure that the sole eligible disk is the intended
installation target.

The barrier intentionally does not pre-realize the complete
`system.build.toplevel`. Therefore dependency, substitution, system-build,
capacity, or bootloader failures may still occur after Disko modifies the
target.

Failures before Disko leave the transaction safe to retry by restarting the
installer service; the next invocation recreates its runtime state from the
immutable base source.

## Installer environment

The installer owns tty1 while interactive. tty1 getty/autovt instances are
disabled and tty2 remains available for diagnostics.

The service wants and starts after `network-online.target`. This is startup
ordering only. A real installer may require network access for locked inputs or
store paths not already available.

The ISO enables the Nix CLI features required by the runtime flake commands.

## Supported environment

The design assumes:

- UEFI firmware capable of booting the standard fallback EFI loader;
- installer media that does not satisfy the target-disk eligibility predicate;
- exactly one intended eligible target disk;
- no second attached installed disk using `PARTLABEL=dotfiles-system`; and
- network access on the real installer when required locked content is absent
  locally.

The installer does not choose among multiple target disks or preserve existing
target data.

## Verification

Verification has two gates.

The **universal gate** evaluates the flake and runs non-VM checks. It does not
require KVM.

The **lifecycle gate** contains the impermanence VM and installer lifecycle E2E.
These are normal NixOS VM tests and require a builder advertising the `kvm`
system feature.

The lifecycle E2E is hermetic: installation succeeds without public Internet,
DNS, or a default route. Required source/store content is provided through test
dependencies or resources available only inside the isolated test environment.

Implementation is complete when the tests prove:

- same-system declared hosts can build installer media even before facter exists;
- ready final NixOS targets consistently use the canonical facter-path contract;
- fixed storage, root reset, persistent state, authentication, and fallback EFI
  boot behave as specified;
- invalid metadata, Disko realization failure, or invalid disk cardinality fail
  before destructive work;
- pre-Disko retry recreates clean transaction state;
- the impermanence VM proves root reset and persistence across reboot; and
- the lifecycle E2E boots the actual ISO, installs to a blank disk, boots the
  installed disk without the ISO, verifies password/sudo, and verifies root
  reset plus persistence.
