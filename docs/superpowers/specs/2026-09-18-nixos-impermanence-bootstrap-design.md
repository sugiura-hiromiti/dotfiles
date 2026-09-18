# NixOS Impermanence Bootstrap and Installer Design

Date: 2026-09-18
Revised: 2026-09-19

## Status

Approved simplified design.

## Purpose

Provide one deterministic path for creating or recreating the current NixOS
host with Disko-backed impermanence.

The system has two separate workflows:

- `nix run .#build-installer -- --host HOST` builds installation media from
  the current pushed `main`;
- `nix run .#update` maintains an already installed machine.

The installer intentionally supports a narrow environment. Unsupported
situations fail before destructive work rather than introducing fallback
machinery.

## Supported environment

The first implementation supports only:

- UEFI machines whose firmware can boot the standard fallback EFI loader from
  the sole internal disk;
- systemd-boot with EFI-variable writes disabled;
- network access during installation;
- installer media that cannot qualify as the install target:
  removable/hotplug USB, optical media, or virtual CD;
- exactly one internal, non-removable, non-hotplug whole disk;
- an anonymously cloneable HTTPS Git `origin`;
- installer images built from `main`;
- no simultaneously attached clone of the same host.

There is no multi-disk target selector, offline installation mode, automatic
boot handoff, kexec fallback, or installer re-entry protocol.

## Ownership

Nix owns:

- installer ISO construction;
- the exact Git commit and `flake.lock` accepted by the installer;
- runtime dependencies and installer scripts;
- NixOS user/authentication policy;
- Disko storage topology;
- preservation policy;
- impermanence/root-reset behavior;
- deterministic and end-to-end tests.

The runtime installer performs only live-machine effects:

- network/Git verification;
- hardware discovery;
- password input and hashing;
- disk discovery and final destructive validation;
- Disko execution;
- persistent secret materialization;
- `nixos-install`;
- verification that systemd-boot installed the standard fallback EFI loader;
- syncing, unmounting, and powering off.

Runtime code MUST NOT introduce a second configuration model independent of
Nix.

## Source of truth

The installable source of truth is the pushed `origin/main` commit from which
the ISO was built.

### Installer-build invariant

The canonical repository URL is declared once in Nix as repository-wide
installer configuration:

```nix
installer.origin = "https://github.com/sugiura-hiromiti/dotfiles.git";
```

It is not host metadata.

`build-installer` MUST require all of the following:

```text
declared installer.origin is anonymously cloneable HTTPS
local Git origin == declared installer.origin
current branch = main
working tree = clean, including untracked files
git fetch origin main succeeds
HEAD = origin/main
```

The builder MUST invoke Nix through the raw local repository path, not an
explicit `path:` flake URL. For a path inside a Git repository this preserves
Git-flake semantics and makes the validated commit available as `self.rev`.

Before building the ISO, the builder also asks real Nix for flake metadata using
that exact raw repository reference and requires the reported revision to equal
the validated Git `HEAD`. A fake-command unit test is not sufficient for this
invariant.

The ISO records only:

- host identity;
- the declared canonical HTTPS `installer.origin`;
- exact commit SHA from the clean flake source.

The installed NixOS target is deterministic for that host: it uses
`runtime.defaultTheme` and `runtime.defaultSession`. The installer builder
does not expose theme/session selection flags.

It does not embed a Git bundle or repository history.

### Installer Git invariant

At install time the installer:

1. requires network access;
2. clones/fetches the configured HTTPS origin;
3. verifies `origin/main` equals the embedded commit;
4. checks out local `main` at that exact commit;
5. completes all reversible preparation;
6. at the final pre-destructive acceptance barrier, fetches `origin/main`
   again and requires it still to equal the embedded commit.

Any mismatch aborts before destructive work.

The freshness invariant is deliberately precise:

> `origin/main` MUST equal the embedded commit at the final
> pre-destructive acceptance barrier.

The remote may advance after that barrier; the installer cannot make an atomic
transaction with GitHub. Such a later change does not alter the already-accepted
installation transaction.

A stale ISO is not allowed to cross the destructive barrier. The remedy is to
build a new ISO.

## Frozen dependencies

Installation MUST NOT update dependency selection.

Every Nix operation that consumes the installation flake MUST use:

```text
--no-update-lock-file
--no-write-lock-file
```

The installer MUST NOT run `nix flake update`.

Missing locked inputs, substitutes, and build dependencies may be fetched from
the network. If the current `flake.nix` would require a lock change, evaluation
or installation fails before destructive work.

`nix run .#update` remains the only normal path that changes `flake.lock`.

## Hardware facts

`nixos-facter` owns observed non-secret hardware facts.

The bootstrap ISO can be built without `facter.json`.

During installation:

1. clone the exact accepted `main`;
2. generate the host's `facter.json`;
3. stage it;
4. create one local commit only when the generated file differs from the
   accepted remote commit.

The final installed NixOS configuration uses:

```nix
hardware.facter.reportPath = ./facter.json;
```

The installer never pushes the facter commit.

After installation the persistent checkout is therefore either:

```text
main == origin/main
```

or:

```text
main = origin/main + one local facter commit
```

Both states are valid for `.#update`.

## Storage model

Disko is the sole owner of installed storage topology.

The target layout is:

```text
GPT
├── ESP          -> /boot
└── system       -> Btrfs
    ├── @root    -> /
    ├── @nix     -> /nix
    └── @persist -> /persist
```

The system partition receives a host-specific GPT partition label. That label is
the persistent block-device identity used by the installed NixOS configuration
and initrd.

No synthetic deterministic Btrfs filesystem UUID is required.

Simultaneously attached clones of the same host are unsupported. If the
host-specific partition label resolves ambiguously during boot, boot/root-reset
logic fails closed rather than choosing one.

Nix evaluation refers to the installation target through the temporary logical
path:

```text
/dev/dotfiles-install-target
```

The installer creates that symlink only after final disk validation.

## Disk-selection contract

The installer does not support disk overrides.

An eligible target is a whole disk with:

```text
removable = false
hotplug   = false
```

Because supported installer media is removable/hotplug/optical/virtual-CD, it
cannot qualify as the target.

During initial preflight the installer scans block devices and requires
exactly one eligible disk.

At the final pre-destructive acceptance barrier, immediately before creating
the target alias and running Disko, it performs the same scan again and again
requires exactly one eligible disk.

If either scan yields zero or more than one candidate, installation aborts.

The first implementation intentionally does not preserve or compare a
cross-time physical-disk identity. Its safety contract is instead that the
supported machine has exactly one eligible internal disk throughout
installation.

## Authentication

The primary administrator chooses a password once during installation.

Nix declares:

- `users.mutableUsers = false`;
- the primary user's `hashedPasswordFile` under `/persist`;
- SSH authorized keys from repository state.

The installer:

1. prompts twice before destructive work;
2. rejects empty or mismatched input;
3. hashes the password in RAM;
4. discards plaintext;
5. after Disko mounts the target, writes only the hash to the evaluated
   persistent path with restrictive permissions.

The installer evaluates the final NixOS configuration for:

- primary home directory;
- password-hash path;
- UID;
- primary group;
- primary-group GID.

It uses those resolved values rather than reconstructing account policy.

## Installer console

The specialized installer ISO reserves `/dev/tty1` exclusively for the
interactive installer service.

The minimal NixOS installation image normally starts an autologin getty on the
first virtual console. This installer MUST suppress that tty1 getty/autovt
ownership so there is never a shell/getty competing with password input.

While `dotfiles-installer.service` is interactive:

- it is the sole reader/writer of `/dev/tty1`;
- `getty@tty1.service` / `autovt@tty1.service` are not active;
- another virtual console may remain available for diagnostics after failure.

## Boot model

The installed system uses systemd-boot and declares:

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = false;
```

The design intentionally does not write UEFI NVRAM variables.

Bootloader installation is owned by the final NixOS configuration and
`nixos-install`. With EFI-variable writes disabled, systemd-boot is installed
to the ESP including the standard architecture-specific fallback loader under:

```text
/EFI/BOOT/BOOT<ARCH>.EFI
```

For the current aarch64 host this is `BOOTAA64.EFI`.

The supported firmware contract is therefore:

> after installer media is removed, firmware can boot the standard fallback
> EFI loader from the sole internal disk.

After `nixos-install`, the installer verifies that the expected fallback loader
exists on the target ESP. It does not inspect or modify EFI variables and does
not use `BootOrder`, `BootNext`, firmware-entry creation, or kexec logic.

Successful installation ends with poweroff. The user removes/ejects the
installer medium before powering the machine on.

## Impermanence

Impermanence owns only root-reset behavior.

The installed configuration:

- mounts `@nix` and `@persist` as persistent subvolumes;
- recreates `@root` during initrd boot;
- uses the host-specific GPT partition label to find the Btrfs system
  partition;
- fails closed if that label does not identify exactly one partition;
- preserves only the repository's intentionally narrow preservation set.

Partitioning and filesystem creation remain Disko responsibilities.

## Installation transaction

Booting the host-specific ISO means:

> recreate this host from the still-current pushed `main` revision recorded
> by the ISO.

Reinstallation is destructive. Existing target data is not preserved.

The transaction is:

```text
boot ISO
↓
require network
↓
clone/fetch HTTPS origin
↓
require origin/main == embedded commit
↓
checkout local main at embedded commit
↓
preflight: require exactly one eligible internal disk
↓
prompt/hash administrator password
↓
generate facter.json
↓
commit facter.json iff changed
↓
evaluate final NixOS configuration
  --no-update-lock-file
  --no-write-lock-file
↓
resolve home / password path / UID / GID
↓
realize Disko provisioning script
↓
──────── final pre-destructive acceptance barrier ────────
git fetch origin main
require origin/main == embedded commit
rescan and require exactly one eligible internal disk
──────────────────────────────────────────────────────────
↓
/dev/dotfiles-install-target -> selected disk
↓
Disko wipes/provisions and mounts target below /mnt
↓
write persistent password hash
↓
nixos-install --root /mnt --flake ...
  --no-update-lock-file
  --no-write-lock-file
↓
verify systemd-boot fallback EFI loader on the target ESP
↓
persist Git checkout under the resolved home backing path
↓
chown using evaluated UID/GID
↓
sync
↓
unmount target filesystems
↓
power off
```

The user then removes/ejects the installer medium and powers the machine on.

There is no custom `BootNext`/`BootOrder` manipulation, completion marker,
installer UUID, automatic media re-entry handling, or kexec path.

## Target-store behavior

After Disko, the future system is mounted below `/mnt`:

```text
/mnt          -> future /
/mnt/boot     -> future /boot
/mnt/nix      -> future /nix
/mnt/persist  -> future /persist
```

`nixos-install --root /mnt` realizes the final closure into the target store:

```text
/mnt/nix/store
```

That same filesystem becomes `/nix/store` after the installed system boots.

The installer does not wipe or copy that store afterward. It only syncs and
unmounts the target before poweroff.

The complete final system closure therefore does not need to fit in the live
ISO's writable store before formatting.

## Persistent repository

The installer persists the accepted repository checkout at:

```text
/mnt/persist + config.users.users.<primary>.home + /dotfiles
```

Ownership comes from the evaluated NixOS UID/GID.

The checkout remains on local `main` with the configured HTTPS `origin`.
It may contain the one local facter commit described above.

## Testing

### Deterministic checks

`nix flake check` covers:

- bootstrap evaluation without `facter.json`;
- facter-backed final-system evaluation;
- Disko storage topology;
- host-specific partition-label generation;
- impermanence/root-reset behavior;
- persistent password policy;
- single-disk selector behavior;
- zero/multiple eligible-disk rejection;
- frozen-lock rejection when a lock mutation would be required;
- raw local Git-flake revision identity used by the installer builder;
- current production host evaluation with fixture facter data.

### Networked installer E2E

The full installer lifecycle runs as a dedicated integration test outside the
Nix build sandbox and may assume network access.

It covers:

1. HTTPS clone of the real fixture origin;
2. rejection when remote `main` already differs from the embedded commit;
3. rejection when remote `main` advances after initial verification but
   before the final destructive barrier, with the target disk unchanged;
4. exclusive tty1 ownership by the installer with no competing getty;
5. successful frozen-lock evaluation;
6. password input;
7. facter generation and conditional local commit;
8. exactly-one-disk validation;
9. Disko provisioning;
10. target-store `nixos-install`;
11. persistent checkout and UID/GID ownership;
12. systemd-boot installation and fallback EFI loader on the target ESP;
13. installer poweroff;
14. boot of the installed system after installer media removal;
15. password login and sudo;
16. Btrfs `@root`, `@nix`, and `@persist`;
17. persistence and ephemeral-root reset across reboot.

The test does not attempt to cover unsupported multi-disk selection, arbitrary
firmware, offline installation, kexec, automatic boot handoff, or simultaneous
host clones.

## Migration from the current host

Migration compatibility is implementation scaffolding, not part of the final
architecture.

The implementation may temporarily keep the existing
`hardware-configuration.nix` path so the currently installed ext4 host still
evaluates while the new installer is being built and tested.

The migration sequence is:

```text
current legacy host remains evaluable
↓
implement and test facter + Disko + impermanence path
↓
build installer from clean pushed main
↓
real installer generates facter.json
↓
new installed system uses final architecture
↓
remove legacy hardware fallback when no longer needed
```

The final architecture does not depend on generated
`hardware-configuration.nix`.

## Non-goals

The first implementation does not support:

- multiple eligible internal disks;
- user-selected disk overrides;
- preserving existing target data during reinstall;
- offline installation;
- installer media that can look like an eligible internal disk;
- building an installer from branches other than `main`;
- installing an ISO whose recorded commit is no longer `origin/main`;
- private/authenticated Git origins;
- detached or dirty installer-build worktrees;
- custom installer-side firmware boot-order manipulation or boot handoff;
- firmware that cannot boot the standard fallback EFI loader from the sole
  internal disk;
- automatic same-media re-entry recovery;
- kexec fallback;
- simultaneous attached clones of one host;
- automatic pushing of facter commits;
- secrets in Git or the Nix store;
- dependency updates during installation.

These may be added later only when there is a demonstrated need.

## Completion invariants

Implementation is complete when:

1. installer build succeeds only when the local Git origin exactly matches the
   declarative HTTPS `installer.origin`, the worktree is clean,
   `main == origin/main`, and the host's declared default theme/session is
   selected;
2. the exact raw local flake reference used for building reports
   `revision == HEAD`, so the ISO's `self.rev` is the validated commit;
3. `origin/main` is re-fetched and must still equal the embedded commit at the
   final pre-destructive acceptance barrier;
4. installation never updates or rewrites dependency selection;
5. final target evaluation occurs after facter generation and before Disko;
6. exactly one eligible internal disk is required both at preflight and at the
   final destructive barrier;
7. the installer is the sole owner of tty1 while interactive;
8. Disko solely owns installed storage topology;
9. the host-specific GPT partition label is the installed storage identity;
10. impermanence owns only root reset and fails closed on ambiguous storage
    identity;
11. the administrator password hash remains outside Git and the Nix store;
12. the full final closure is realized only after the target `/nix` exists;
13. the persistent checkout uses evaluated home/UID/GID values;
14. systemd-boot and the standard fallback EFI loader are installed by the
    final NixOS configuration through `nixos-install`, without EFI-variable
    writes;
15. successful installation ends with sync, unmount, and poweroff;
16. first boot requires the user to remove/eject installer media and power on;
17. `.#update` remains the only normal dependency-update path;
18. deterministic checks and one networked E2E cover the supported contract.
