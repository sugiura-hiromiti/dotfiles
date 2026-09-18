# NixOS Impermanence Bootstrap and Installer Design

Date: 2026-09-18
Revised: 2026-09-19

## Status

Approved pruned design.

## Purpose

Provide one deterministic path for creating or recreating any declared NixOS
host with Disko-backed impermanence.

The system has two separate workflows:

- `nix run .#build-installer -- --host HOST` builds host-specific installation
  media from the exact Git revision currently published as the repository's
  anonymous HTTPS `main`;
- `nix run .#update` maintains an already installed machine.

The installer intentionally supports a narrow environment. Unsupported
situations fail before destructive work rather than introducing fallback
machinery.

## Supported environment

The first implementation supports only:

- UEFI firmware capable of booting the standard fallback EFI loader from the
  sole internal disk;
- systemd-boot with EFI-variable writes disabled;
- network access during installation;
- installer media that cannot qualify as the install target:
  removable/hotplug USB, optical media, or virtual CD;
- exactly one internal, non-removable, non-hotplug whole disk at the destructive
  acceptance barrier;
- an anonymously cloneable HTTPS Git repository;
- NixOS hosts declared by the repository;
- no concurrently attached second installed dotfiles disk using the fixed
  system partition label.

There is no multi-disk target selector, offline installation mode, automatic
boot handoff, kexec fallback, installer re-entry protocol, or
`hardware-configuration.nix` compatibility layer.

## Canonical repository identity

The canonical installer origin is declared once in Nix:

```nix
installer.origin = "https://github.com/sugiura-hiromiti/dotfiles.git";
```

The local checkout's branch name, detached/attached state, configured Git
remotes, and untracked files are not part of installer identity.

The build identity is the Git revision reported by Nix for the raw local
repository flake.

### Builder acceptance

`build-installer --host HOST`:

1. asks real Nix for metadata of the raw local repository flake with
   `--no-update-lock-file`;
2. requires a concrete `revision` field, which excludes a dirty tracked Git
   tree;
3. reads `refs/heads/main` from the declared HTTPS origin using anonymous
   `git ls-remote` with interactive credentials/config disabled;
4. requires the Nix flake revision to equal that remote `main` SHA;
5. builds `<raw-repository>#installer-HOST`.

Untracked files are intentionally ignored because raw Git-flake semantics ignore
them.

The builder never converts the repository to an explicit `path:` flake.

The ISO receives from Nix the already-resolved values needed at runtime,
including:

- host;
- final NixOS target name using the host's normalized default theme/session;
- primary account;
- canonical HTTPS origin;
- exact source commit;
- EFI architecture.

No installer-specific public host metadata output is required.

## Git-flake semantics

Raw Git-flake references are used consistently by the installer design.

At build time the raw repository provides the source commit through
`self.rev`.

At installation time the cloned repository is also evaluated as a raw Git
flake. The installer commits generated `facter.json` before final evaluation,
so the runtime checkout is a clean Git revision and does not require
`path:` semantics.

## Frozen dependencies

Installation MUST NOT update dependency selection.

Every installer-side Nix command consuming the cloned flake uses:

```text
--no-update-lock-file
```

The installer MUST NOT pass `--no-write-lock-file`. With the pinned Nix
semantics, `--no-update-lock-file` is the fail-closed control: if evaluation
would require a lock change, Nix aborts.

The installer MUST NOT run `nix flake update`.

Missing already-locked inputs, substitutes, and build dependencies may be
fetched from the network.

`nix run .#update` remains the normal workflow that intentionally changes
`flake.lock`.

## Hardware facts

`nixos-facter` is the sole hardware-description mechanism for final NixOS
configurations.

Every evaluated NixOS host requires:

```nix
hardware.facter.reportPath = ./facter.json;
```

There is no fallback to `hardware-configuration.nix`.

The bootstrap ISO is intentionally constructed without evaluating the final
NixOS configuration, so an installer can still be built for a newly declared
host before that host has `facter.json`.

During installation:

1. clone public `main` into a local `main` branch;
2. require its HEAD to equal the embedded commit;
3. generate `nix/profiles/hosts/<host>/facter.json`;
4. stage it;
5. create one local commit only when the generated file differs.

The local facter commit is never pushed by the installer.

## Final NixOS target

The host registry already normalizes:

- primary account;
- default theme;
- default session;
- runtime target axes.

Installer package generation derives the final target directly from that
normalized host metadata and the existing target naming rules.

`build-installer --host HOST` remains generic. It does not expose
theme/session/account selection flags.

## Fixed storage topology

The first implementation has one storage layout, not a configurable storage
API:

```text
GPT
├── ESP               -> /boot
└── dotfiles-system   -> Btrfs
    ├── @root         -> /
    ├── @nix          -> /nix
    └── @persist      -> /persist
```

The GPT system partition label is always:

```text
dotfiles-system
```

The subvolume names are always:

```text
@root
@nix
@persist
```

Disko is the sole owner of partitioning, filesystem creation, subvolume
creation, and mount definitions.

The Disko target device is the fixed temporary installer alias:

```text
/dev/dotfiles-install-target
```

There is no public storage-device option, no filesystem UUID identity, no
configurable partition label, no configurable subvolume names, and no
provisioning enable flag.

Attaching another installed dotfiles disk with the same fixed partition label is
outside the supported boot environment. Initrd root-reset logic nevertheless
fails closed unless exactly one partition has `PARTLABEL=dotfiles-system`.

## Impermanence

Impermanence owns root reset and persistence policy, not storage topology.

When enabled for the final NixOS configuration it:

- requires exactly one `dotfiles-system` partition in initrd;
- mounts the Btrfs top level temporarily;
- deletes existing `@root`;
- recreates `@root` before `sysroot.mount`;
- marks `/nix` and `/persist` as needed for boot;
- enables the repository's intentionally narrow preservation policy.

The root-reset implementation is internal to the impermanence feature. There is
no separately configurable public `ephemeralRoot` interface.

## Authentication

The final NixOS configuration declares directly:

```nix
users.mutableUsers = false;
users.users.<primary>.hashedPasswordFile =
  "/persist/etc/dotfiles/password-<primary>.hash";
```

SSH authorized keys remain repository state.

There is no bootstrap-credentials wrapper module or duplicate hash-path option.

The installer:

1. prompts twice;
2. rejects empty or mismatched input;
3. hashes the password with yescrypt in RAM;
4. discards plaintext;
5. evaluates the final NixOS configuration;
6. reads the authoritative `hashedPasswordFile`, home, UID, primary group, and
   GID from that configuration;
7. after Disko mounts `/persist`, writes only the hash to
   `/mnt + hashedPasswordFile` with restrictive permissions.

Secret material never enters Git or the Nix store.

## Installer console

The specialized installer ISO reserves `/dev/tty1` exclusively for the
interactive installer service.

The minimal NixOS installation image's tty1 getty/autologin is suppressed.
Another virtual console may remain available for diagnostics.

While the installer is interactive:

- `dotfiles-installer.service` is the sole reader/writer of tty1;
- `getty@tty1.service` and `autovt@tty1.service` are not running.

## Destructive acceptance barrier

All preparation before disk modification is reversible.

Immediately before creating `/dev/dotfiles-install-target` and invoking Disko,
the installer performs one acceptance barrier:

1. anonymously reads remote `refs/heads/main` with `git ls-remote`;
2. requires that SHA to equal the embedded commit;
3. scans whole block devices;
4. requires exactly one device with `RM=0` and `HOTPLUG=0`.

There is no earlier disk preflight and no cross-time disk identity.

If either acceptance check fails, the installer exits with the target untouched.

The remote may advance after this barrier; no atomic transaction with GitHub is
claimed beyond the barrier.

## Installation transaction

The transaction is:

```text
boot ISO
↓
require network
↓
git clone --branch main --single-branch <origin>
↓
require cloned HEAD == embedded commit
↓
prompt/hash administrator password
↓
generate facter.json
↓
commit facter.json iff changed
↓
evaluate final NixOS target from raw Git checkout
  --no-update-lock-file
↓
resolve hashedPasswordFile / home / UID / primary group / GID
↓
realize Disko script
  --no-update-lock-file
↓
──────── final destructive acceptance barrier ────────
anonymous ls-remote origin main == embedded commit
exactly one eligible internal whole disk
──────────────────────────────────────────────────────
↓
/dev/dotfiles-install-target -> selected disk
↓
Disko provisions GPT + ESP + Btrfs + fixed subvolumes
↓
write persistent password hash
↓
nixos-install --root /mnt --flake <raw-checkout>#<target>
  --no-update-lock-file
↓
verify /mnt/boot/EFI/BOOT/BOOT<ARCH>.EFI
↓
copy complete Git checkout into /mnt/persist + <home> + /dotfiles
↓
chown checkout using evaluated UID/GID
↓
sync
↓
unmount /mnt recursively
↓
power off
```

The copied checkout is already the validated checkout; the installer does not
re-validate branch/origin/HEAD after copying it.

The user removes/ejects the installer medium and powers the machine on.

## Boot model

The installed system declares:

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = false;
```

`nixos-install` installs systemd-boot and the standard fallback loader:

```text
/EFI/BOOT/BOOT<ARCH>.EFI
```

The installer verifies that fallback file on the target ESP.

There is no EFI-variable manipulation, `BootOrder`, `BootNext`, firmware
entry creation, kexec, completion marker, or same-media re-entry mechanism.

## Target-store behavior

After Disko:

```text
/mnt          -> future /
/mnt/boot     -> future /boot
/mnt/nix      -> future /nix
/mnt/persist  -> future /persist
```

`nixos-install --root /mnt` realizes the final closure into
`/mnt/nix/store`.

The complete final closure is therefore not realized before the destructive
barrier and does not need to fit in the live ISO store.

## Persistent repository

The installer copies the runtime checkout to:

```text
/mnt/persist + <evaluated primary home> + /dotfiles
```

and assigns the evaluated UID/GID.

Because the source checkout itself was already validated, the copy operation is
not followed by redundant Git branch/origin/revision checks.

## Testing strategy

Keep tests at two levels.

### Deterministic checks

`nix flake check` covers cheap structural and transaction invariants:

- final NixOS evaluation requires facter and has no legacy hardware fallback;
- fixed Disko topology and fixed partition/subvolume names;
- direct persistent password policy;
- root-reset evaluation and duplicate-PARTLABEL rejection logic;
- single-disk selector zero/one/multiple behavior;
- stale-remote failure at the final barrier before Disko;
- `--no-update-lock-file` rejection when a lock mutation would be required;
- raw Git-flake revision semantics used by the builder;
- installer tty1 unit configuration.

### One lifecycle E2E

A dedicated networked test:

```text
nix run .#test-installer-e2e
```

boots the actual ISO and covers the supported lifecycle:

1. tty1 belongs exclusively to the installer;
2. anonymous HTTPS clone succeeds;
3. fresh facter is generated and conditionally committed;
4. final target evaluates from the raw Git checkout;
5. the final remote/disk acceptance barrier succeeds;
6. Disko provisions the fixed topology;
7. target-store `nixos-install` succeeds;
8. fallback EFI loader exists;
9. persistent checkout has evaluated ownership;
10. installer powers off;
11. installed disk boots with installer media removed;
12. password login and sudo work;
13. `@root` resets while `@nix`, `@persist`, preserved state, and the
    checkout survive reboot.

Historical intermediate VM tests that duplicate this lifecycle are removed
rather than maintained in parallel.

## Non-goals

The first implementation does not support:

- choosing theme/session/account at installer-build time;
- multiple eligible internal disks;
- target-disk overrides;
- configurable partition labels or subvolume names;
- attaching multiple installed dotfiles disks at boot;
- preserving target data on reinstall;
- offline installation;
- installer media that looks like an eligible internal disk;
- private/authenticated Git origins;
- requiring the local checkout to be on branch `main`;
- requiring a particular local `origin` remote;
- rejecting harmless untracked files;
- `hardware-configuration.nix` fallback;
- filesystem UUID identity;
- EFI-variable writes;
- automatic firmware boot handoff;
- kexec;
- automatic pushing of facter commits;
- dependency updates during installation.

## Completion invariants

Implementation is complete when:

1. `build-installer --host HOST` works generically for declared NixOS hosts;
2. the builder uses the raw Git flake and accepts it only when Nix reports a
   concrete revision equal to anonymous HTTPS `main`;
3. no installer flow uses explicit `path:` flake semantics;
4. final NixOS evaluation requires `facter.json` and has no legacy fallback;
5. every installer-side flake evaluation/build/install uses
   `--no-update-lock-file` without `--no-write-lock-file`;
6. the final destructive barrier revalidates remote `main` and requires
   exactly one eligible internal disk;
7. Disko alone owns the fixed GPT/ESP/Btrfs topology;
8. initrd root reset fails closed unless exactly one `dotfiles-system`
   partition exists;
9. the final configuration directly owns password-file policy;
10. the installer alone owns tty1 while interactive;
11. the final closure is realized only after target `/mnt/nix` exists;
12. systemd-boot fallback boot works without EFI-variable writes;
13. successful installation ends with sync, unmount, and poweroff;
14. cheap deterministic tests plus one lifecycle E2E cover the supported
    contract.
