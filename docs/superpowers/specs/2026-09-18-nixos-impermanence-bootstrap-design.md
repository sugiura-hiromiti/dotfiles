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
evaluation. `self.outPath` is therefore the exact immutable base installer
snapshot.

The builder and ISO consume that base snapshot directly. Each runtime installer
service invocation creates exactly one host-materialized tree by copying the base to
`/run/dotfiles-installer/source` and adding fresh `facter.json`. After facter
generation, that tree is no longer modified. All final NixOS evaluation, Disko
realization, and flake-based installation operations use `path:` semantics over
that same host-materialized tree. Repeated evaluation is allowed; additional
Git/refetch/filter-based source reconstruction is not.

The source directory itself is the boundary. Files that must never enter an
installer snapshot must live outside it.

A `.git` directory may therefore be physically present in the snapshot. It is
semantically inert: installer code must not inspect it or derive behavior from
Git history, refs, remotes, index state, or cleanliness.

The explicit-path source contract also applies to generated CI: every Nix
command that evaluates this repository names `path:.` explicitly. Commands
that do not evaluate the repository, such as `nix --version`, are outside that
rule.

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
`hardware.facter.reportPath`. Exported NixOS configurations, every check that
dereferences them, and generated CI targets that dereference them are derived
from the same facter-ready target-entry set; there is no separate unfiltered
NixOS check or CI target-name source.

A representative NixOS CI target is optional. When there is no facter-ready
representative, CI generation remains valid and omits only NixOS-specific
evaluation/build references. This is required so the bootstrap state
"declared NixOS host, no facter report yet" can still evaluate its installer
package/app.

During installation the embedded source is copied to writable runtime storage,
fresh `facter.json` is generated there, and final-config metadata is evaluated
from that host-materialized tree using `path:` flake semantics. Later Disko
realization and `nixos-install --flake` may evaluate the same final target again;
this is intentional because the host-materialized source is no longer mutated.

The installer ISO explicitly enables the `nix-command` and `flakes`
experimental features because the runtime transaction invokes bare `nix eval`
and `nix build` flake commands.

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
path from the evaluated final NixOS configuration. Before Disko it requires UID
and GID to be integers, group to be non-empty, home to be an absolute normalized
non-root path with no `..` traversal component, and the password path to equal
exactly `/persist/etc/dotfiles/password-<primary>.hash`.

The installed bootloader contract is:

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = false;
```

The baseline boot module may continue to provide these as composable defaults,
but every installer-compatible final NixOS configuration asserts the effective
values after module merging. A host/profile override that violates either value
therefore makes final configuration evaluation fail.

Boot relies on the standard fallback EFI loader at:

```text
/EFI/BOOT/BOOT<ARCH>.EFI
```

## Installation flow

```text
boot ISO
↓
discard stale installer-owned /run state and stale install-target symlink
↓
copy embedded base source to /run/dotfiles-installer/source
↓
prompt twice and hash administrator password
↓
generate facter.json in the writable source
↓
evaluate final metadata with --no-update-lock-file
↓
validate absolute safe home / UID / primary group / GID
and exact /persist/etc/dotfiles/password-<primary>.hash
↓
realize Disko script with --no-update-lock-file
↓
require exactly one whole disk where lsblk JSON has
type == "disk", rm == false, hotplug == false
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

All destructive work starts only after final metadata evaluation,
Disko-script realization, policy/path validation, and the exactly-one-disk check
succeed.

This barrier intentionally does not prove that the complete
`system.build.toplevel` can already be realized. `nixos-install --flake`
realizes the final system in the target store after Disko, so dependency,
substitution, system-build, disk-capacity, or bootloader failures may still
occur after the target disk has been modified. Pre-realizing the full system in
the live ISO store is explicitly outside this design.

The installer service owns tty1 while interactive. tty1 getty/autovt instances
are masked and tty2 remains available for diagnostics.

The installer wants and starts after `network-online.target` because locked Nix
inputs may need runtime fetching. This target provides boot ordering only; it is
not treated as proof of Internet reachability.

Each invocation owns fresh transaction state under
`/run/dotfiles-installer`. Before any destructive work it recreates the
host-materialized source from the immutable base and removes a stale
`/dev/dotfiles-install-target` only when that path is a symlink; an unexpected
non-symlink object at that path is an error.

A network/fetch failure before Disko leaves tty2 available. After repairing
connectivity, restarting `dotfiles-installer.service` starts from fresh
transaction state. Failures after Disko are outside this non-destructive retry
guarantee.

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
3. the builder and ISO use one immutable `self.outPath` base snapshot, while
   every installer invocation derives a fresh facter-enriched host-materialized
   tree from it and performs all final NixOS operations from that unmodified
   per-invocation tree;
4. default installer target selection uses declared runtime defaults and does
   not change when runtime-list ordering changes;
5. facter-less hosts can build installer media without exporting final
   `nixosConfigurations`; representative NixOS CI references are optional and
   neither checks nor generated CI reference configurations removed by the
   readiness filter;
6. the production host profile contains no legacy filesystem/swap/facter
   ownership;
7. final NixOS configurations use facter, fixed Disko storage, impermanent
   `@root`, effective user/group ownership, the exact persistent credential
   path, asserted systemd-boot/no-EFI-variable policy, and fallback EFI boot;
8. installation fails before destructive work when metadata/policy/path
   validation fails, Disko realization fails, lock mutation would be required,
   or the eligible-disk count is not one; full-system realization is explicitly
   allowed to fail after Disko;
9. tty1 remains exclusively installer-owned during interaction; the installer
   starts after `network-online.target`, and a pre-Disko connectivity failure
   can be retried from fresh transaction state using tty2 plus a service restart;
10. one deterministic VM proves root reset/persistence across reboot;
11. one lifecycle E2E boots the actual ISO, installs to a blank disk, boots the
    installed disk without the ISO, verifies password/sudo, and verifies
    persistence/root reset;
12. every generated CI command that evaluates this repository uses an
    explicit `path:.` flake operand;
13. the implementation stops after building and testing the ISO and does not
    boot it on the user's real machine.
