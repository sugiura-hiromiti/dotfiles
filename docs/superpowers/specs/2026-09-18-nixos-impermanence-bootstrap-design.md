# NixOS Impermanence Bootstrap Design

Date: 2026-09-18
Revised: 2026-09-19

## Purpose

Provide one generic command for creating installation media for any declared
NixOS host:

```text
nix run --impure .#build-installer -- --host HOST
```

The installer consumes the current dotfiles filesystem contents, not Git
history. It installs a facter-backed NixOS system with one fixed
Disko/impermanence layout, then powers off for manual installer-media removal.

The existing `.#update` workflow is outside this design.

## Source and configuration

The builder reads the current working directory through an impure flake
evaluation and immediately converts it to an immutable filtered store path:

```nix
pkgs.nix-gitignore.gitignoreSource [ ] sourceRoot
```

The repository's `.gitignore` is the source-selection policy. This includes
current non-ignored files, including non-ignored untracked files, while
excluding ignored local state and `.git`.

The filter runs before the source enters the Nix store. ISO construction uses
only that immutable store path.

Installer packages are generated for every declared NixOS host and use the
host's existing normalized:

- system;
- primary account;
- default theme;
- default session;
- target-axis policy.

The final target name is derived with the existing target naming rules.

Final `nixosConfigurations` are exported only for hosts that have:

```text
nix/profiles/hosts/<host>/facter.json
```

Every exported NixOS configuration uses that file through
`hardware.facter.reportPath`. There is no alternate hardware-description
path.

During installation the embedded source is copied to writable runtime storage,
fresh `facter.json` is generated there, and the final target is evaluated from
that writable tree using `path:` flake semantics.

Installer-side Nix operations use:

```text
--no-update-lock-file
```

so installation cannot change dependency selection.

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

During installation Disko receives the selected disk through:

```text
/dev/dotfiles-install-target
```

Impermanence resets only `@root`. In initrd it requires exactly one partition
with `PARTLABEL=dotfiles-system`, deletes the previous `@root`, recreates
it, and keeps `/nix` and `/persist` available for boot.

The primary account uses immutable password configuration:

```nix
users.mutableUsers = false;
users.users.<primary>.hashedPasswordFile =
  "/persist/etc/dotfiles/password-<primary>.hash";
```

The installer writes only the password hash to that evaluated path.

The installed bootloader is:

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = false;
```

Boot therefore relies on the standard fallback EFI loader at:

```text
/EFI/BOOT/BOOT<ARCH>.EFI
```

The installer verifies that file after `nixos-install`.

## Installation flow

```text
boot ISO
↓
copy embedded filtered source to /run/dotfiles-installer/source
↓
prompt twice and hash administrator password
↓
generate facter.json in the writable source
↓
evaluate final target with --no-update-lock-file
↓
resolve home / UID / primary group / GID / hashedPasswordFile
↓
realize Disko script with --no-update-lock-file
↓
require exactly one non-removable, non-hotplug whole disk
↓
/dev/dotfiles-install-target -> selected disk
↓
Disko provisions and mounts /mnt
↓
write password hash under /mnt/persist
↓
nixos-install --root /mnt from the writable source
↓
verify fallback EFI loader
↓
copy writable dotfiles source to /mnt/persist + <home> + /dotfiles
↓
chown with evaluated UID/GID
↓
sync, unmount, power off
```

All destructive work starts only after final target evaluation, Disko-script
realization, and the exactly-one-disk check succeed.

The installer service owns tty1 while interactive. tty1 getty/autovt instances
are masked, tty2 remains available for diagnostics, and the installer service
uses a long-running service type appropriate for an interactive process.

## Assumptions

The supported environment has:

- UEFI firmware able to boot the standard fallback EFI loader;
- installer media that does not qualify as the internal target disk;
- exactly one eligible internal whole disk;
- network access when locked Nix dependencies must be fetched;
- no second attached installed disk using `PARTLABEL=dotfiles-system`.

The installer does not choose among multiple target disks or preserve existing
target-disk data.

## Acceptance

Implementation is complete when:

1. `build-installer --host HOST` works for declared NixOS hosts and embeds the
   filtered current filesystem snapshot;
2. facter-less hosts can build installer media without exporting final
   `nixosConfigurations`;
3. final NixOS configurations use facter, the fixed Disko topology,
   impermanent `@root`, persistent credentials, and fallback EFI boot;
4. installation fails before destructive work when final evaluation fails,
   lock mutation would be required, or the eligible-disk count is not one;
5. tty1 remains exclusively installer-owned during interaction;
6. one deterministic VM proves root reset/persistence across reboot;
7. one lifecycle E2E boots the actual ISO, installs to a blank disk, boots the
   installed disk without the ISO, verifies password/sudo, and verifies
   persistence/root reset;
8. the implementation stops after building and testing the ISO and does not
   boot it on the user's real machine.
