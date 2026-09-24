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

Cross-system installer builds, VCS history semantics, and the existing update
workflow are out of scope.

## Source identity

JJ selects the current versioned path set. `build-installer` copies the current
filesystem contents of those paths into a fresh staging directory outside the
checkout, preserving paths, symlinks, and executable bits.

The installer package is built directly from that staged flake:

```text
path:<stage>#installer-HOST
```

Nix provides the staged flake's immutable content-addressed `self.outPath`;
that path is the **base source** carried by the ISO. Ignored, unversioned, and
generated checkout contents are outside the source boundary. VCS history and
refs do not participate in source identity.

The build produces no checkout-local out-link; the resulting installer store
path is reported directly.

At runtime the installer creates one writable working tree:

```text
/run/dotfiles-installer/source
```

It restores owner-write permission, generates the host's `facter.json`, then
adds that complete tree to the Nix store exactly once. The returned
**post-facter store path** is the transaction source identity.

Metadata evaluation, Disko realization, and `nixos-install --flake` all use
that same post-facter store path. The writable tree is not evaluated after this
snapshot exists, and the store path remains rooted for the transaction lifetime.

## Lock graph

Every bootstrap and installer flake operation uses `--no-update-lock-file`.
If the existing lock graph cannot satisfy an operation, that operation fails
instead of updating dependencies.

## Hosts, targets, and facter readiness

`host` is the host-registry key; `hostName` is the hostname configured inside
the operating system.

Installer packages exist for declared same-system NixOS hosts and use the
host's declared default runtime target. Target naming/default selection belongs
to the target model.

A declared host may build installer media before its facter report exists.
Final `nixosConfigurations` exist only for facter-ready hosts.

One canonical host/facter-path contract drives host discovery, readiness,
`hardware.facter.reportPath`, installer facter placement, checks, and CI.

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

The selected installation disk is exposed to Disko as
`/dev/dotfiles-install-target`. Storage device, partition label, and subvolume
names are internal constants.

Impermanence resets only `@root`. Initrd requires exactly one
`PARTLABEL=dotfiles-system` device, recreates `@root`, and leaves `@nix` and
`@persist` intact. The reset service carries its executable dependencies in
its own initrd environment.

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

The installer service uses `UMask=0077`. The password directory is
`root:root 0700`; the hash is `root:root 0600` and is installed atomically
via a same-directory temporary file.

The installed `/`, `/nix`, `/persist`, and `/persist/etc` directories are
`0755`, allowing normal users to access the system and persisted machine ID.
These directory modes are established explicitly despite the private service
umask.

The installed system uses:

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = false;
```

Those values are asserted after module merging. Boot uses
`/EFI/BOOT/BOOT<ARCH>.EFI`.

## Preservation contract

The primary user's `dotfiles` directory is preserved under `/persist`.

Final configuration metadata supplies the physical backing path; the installer
does not derive Preservation path rules itself. For the current layout:

```text
backing path: /persist<evaluatedHome>/dotfiles
install path: /mnt/persist<evaluatedHome>/dotfiles
runtime path: <evaluatedHome>/dotfiles
```

The persisted tree preserves executable bits, is owner-writable, and is owned
by the evaluated UID:GID.

## Installation transaction

```text
sanitized staged flake
→ immutable base source
→ writable facter workspace
→ immutable post-facter store snapshot
→ validate final metadata
→ realize Disko script
→ validate exactly one eligible target disk
→ create /dev/dotfiles-install-target
→ Disko provisions /mnt
→ validate mounts and establish traversable system-directory permissions
→ write root-only persistent password hash atomically
→ nixos-install from the same post-facter source
→ verify fallback EFI loader
→ copy dotfiles to the evaluated Preservation backing path
→ sync, unmount, power off
```

Each service invocation starts with fresh installer-owned runtime state. It may
replace its own stale target symlink; an unexpected non-symlink at that path is
an error.

## Destructive barrier

No target-disk modification occurs before these succeed against the same
post-facter source and lock graph:

1. final metadata evaluation;
2. administrator and boot-policy validation;
3. Disko-script realization; and
4. target-disk validation.

An eligible target is a whole disk with `TYPE=disk`, `RM=false`, and
`HOTPLUG=false`. Exactly one must exist. The environment is responsible for
making the intended installation disk the sole eligible disk.

The barrier does not pre-realize `system.build.toplevel`, so later
install-time failures remain possible after Disko modifies the target.

Failures before Disko are retry-safe: restarting recreates runtime state from
the immutable base source and derives a fresh post-facter snapshot.

## Installer environment

The installer owns tty1; tty2 remains available for diagnostics. It starts
after and wants `network-online.target`.

The real installer may require network access for locked content not already
available locally. Supported installation assumes UEFI fallback-loader support,
one intended eligible target disk, no second attached
`PARTLABEL=dotfiles-system` disk, and installer media that is not itself
eligible.

## Verification

Verification has three layers:

- **evaluation:** `nix flake check --no-build .`;
- **universal:** evaluation plus `checks.<system>.non-vm`;
- **lifecycle:** the impermanence VM and installer E2E, using KVM when
  available and QEMU software emulation otherwise.

Hosted CI runs evaluation and universal checks only.

On Linux, prepare the evaluation gate by instantiating
`checks.<system>.installer-e2e.drvPath` with `nix eval --no-update-lock-file
--option allow-import-from-derivation false --raw`. This writes derivations
without building or running a VM. Nix's read-only `flake check --no-build`
evaluator cannot traverse fresh derivation store paths for the ISO's offline
build closure. CI runs this preparation before the unchanged evaluation gate.

Non-VM tests cover source selection, frozen-lock behavior, facter readiness,
post-facter identity, root-device cardinality, destructive-barrier failures,
password permissions, Preservation backing paths, retry behavior, fixed
storage, and generated CI.

The hermetic lifecycle E2E boots the actual ISO, installs to one blank eligible
disk, verifies the backing password/dotfiles state before unmount, boots without
the ISO, verifies login/sudo and writable preserved dotfiles, then proves root
reset and persistence across reboot.
