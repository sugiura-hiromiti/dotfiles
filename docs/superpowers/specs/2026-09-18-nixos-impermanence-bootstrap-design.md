# NixOS Impermanence Bootstrap Design

Date: 2026-09-18
Revised: 2026-09-19

## Purpose

Provide one command for creating installation media for a declared NixOS host
on the current system:

```text
nix run path:.#build-installer -- --host HOST
```

The `path:` input is the source contract: the installer is built from the
current filesystem tree as it exists at invocation time.

The installer produces a facter-backed NixOS system with one fixed
Disko/impermanence layout, then powers off for manual installer-media removal.

Cross-system installer builds and the existing `.#update` workflow are outside
this design.

## Source and configuration

`path:.` copies the source tree to an immutable Nix store path before flake
evaluation. `self.outPath` is therefore the exact installer source snapshot.

No second source-snapshot mechanism is needed. The builder, ISO, runtime
installer, and E2E all consume that same snapshot.

The source directory itself is the boundary. Files that must never enter an
installer snapshot must live outside it.

A `.git` directory may therefore be physically present in the snapshot. It is
semantically inert: installer code must not inspect it or derive behavior from
Git history, refs, remotes, index state, or cleanliness.

Installer packages are generated for declared NixOS hosts whose `system`
matches the current `perSystem` system.

For a host, the installer target is exactly:

```nix
targetNames.mkSystemTargetName {
  inherit (host) targetHost;
  inherit (host.runtime) targetAxes;
  themeName = host.runtime.defaultTheme;
  sessionName = host.runtime.defaultSession;
}
```

so target selection is independent of the ordering of `runtime.themes` and
`runtime.sessions`.

Here, `host` means the host-registry key (for example
`aarch64-linux-a`). `hostName` means only the hostname configured inside
the operating system.

Final `nixosConfigurations` are exported only for entries whose
`entry.config.host` has:

```text
nix/profiles/hosts/<host>/facter.json
```

Every exported NixOS configuration uses that file through
`hardware.facter.reportPath`.

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

The host-specific profile owns only host-specific policy. Universal hardware,
storage, and password policy are owned by constructed NixOS configuration, so
the production host profile does not declare its own filesystems, swap, or
`hardware.facter.reportPath`.

The primary account uses immutable password configuration:

```nix
users.mutableUsers = false;
users.users.<primary>.hashedPasswordFile =
  "/persist/etc/dotfiles/password-<primary>.hash";
```

The installer reads the effective home, UID, primary group, GID, and password
path from the evaluated final NixOS configuration.

The installed bootloader is:

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = false;
```

Boot relies on the standard fallback EFI loader at:

```text
/EFI/BOOT/BOOT<ARCH>.EFI
```

## Installation flow

```text
boot ISO
↓
copy embedded source to /run/dotfiles-installer/source
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
are masked and tty2 remains available for diagnostics.

## Assumptions

The supported environment has:

- a source directory containing only files acceptable to copy into the Nix store
  and installer snapshot;
- UEFI firmware able to boot the standard fallback EFI loader;
- installer media that does not qualify as the internal target disk;
- exactly one eligible internal whole disk;
- network access when locked Nix dependencies must be fetched;
- no second attached installed disk using `PARTLABEL=dotfiles-system`.

The installer does not choose among multiple target disks or preserve existing
target-disk data.

## Acceptance

Implementation is complete when:

1. `nix flake check -L path:.` passes from the current filesystem snapshot;
2. `nix run path:.#build-installer -- --host HOST` works for same-system
   declared NixOS hosts;
3. the builder and ISO use `self.outPath` from that same immutable `path:`
   snapshot without a second snapshot/filter stage;
4. default installer target selection uses declared runtime defaults and does
   not change when runtime-list ordering changes;
5. facter-less hosts can build installer media without exporting final
   `nixosConfigurations`;
6. the production host profile contains no legacy filesystem/swap/facter
   ownership;
7. final NixOS configurations use facter, fixed Disko storage, impermanent
   `@root`, effective user/group ownership, persistent credentials, and
   fallback EFI boot;
8. installation fails before destructive work when final evaluation fails,
   lock mutation would be required, or the eligible-disk count is not one;
9. tty1 remains exclusively installer-owned during interaction;
10. one deterministic VM proves root reset/persistence across reboot;
11. one lifecycle E2E boots the actual ISO, installs to a blank disk, boots the
    installed disk without the ISO, verifies password/sudo, and verifies
    persistence/root reset;
12. the implementation stops after building and testing the ISO and does not
    boot it on the user's real machine.
