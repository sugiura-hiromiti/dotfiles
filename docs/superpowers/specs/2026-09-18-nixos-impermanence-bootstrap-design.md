# NixOS Impermanence Bootstrap and Installer Design

Date: 2026-09-18
Revised: 2026-09-19

## Status

Approved snapshot-source design.

## Purpose

Provide one deterministic path for creating or recreating any declared NixOS
host with Disko-backed impermanence.

The installer consumes the **current dotfiles filesystem snapshot**. Git
history, commits, branches, remotes, staging state, and repository cleanliness
are outside the installer correctness model.

The two operator workflows are:

```text
nix run path:.#build-installer -- --host HOST
nix run path:.#update
```

The explicit `path:.` is intentional: operational commands use the current
filesystem contents rather than Git-flake visibility rules.

## Supported environment

The first implementation supports only:

- UEFI firmware capable of booting the standard fallback EFI loader from the
  sole internal disk;
- systemd-boot with EFI-variable writes disabled;
- network access when Nix must fetch locked inputs, substitutes, or build
  dependencies;
- installer media that cannot qualify as the install target:
  removable/hotplug USB, optical media, or virtual CD;
- exactly one internal, non-removable, non-hotplug whole disk at the destructive
  acceptance barrier;
- declared NixOS hosts;
- no concurrently attached second installed dotfiles disk using the fixed
  system partition label.

There is no multi-disk selector, target override, offline guarantee, automatic
boot handoff, kexec fallback, installer re-entry protocol, or
`hardware-configuration.nix` compatibility layer.

## Dotfiles source snapshot

The build input is a filtered immutable Nix store snapshot of the current
filesystem tree.

For each system, derive:

```nix
dotfilesSource =
  pkgs.nix-gitignore.gitignoreSource [ ] self.outPath;
```

When the operator invokes the flake with `path:.`, `self.outPath` represents
the current filesystem contents. `nix-gitignore` then applies the root
`.gitignore` plus its built-in `.git` exclusion.

The `.gitignore` file is therefore reused only as a declarative source-filter
policy. No Git executable, index, commit, branch, remote, or history is consulted
to construct the snapshot.

This prevents ignored local state such as credentials, histories, caches,
build outputs, `.jj`, and `.direnv` from entering the installer source.

The snapshot is immutable once copied to the Nix store. The builder and ISO use
that exact store path, so there is no source TOCTOU between validation and
build.

## Generic installer target

`build-installer --host HOST` remains generic.

The host registry already normalizes:

- system;
- target kind;
- primary account;
- default theme;
- default session;
- runtime target axes.

Installer package generation derives the final target name directly from those
existing fields and the existing target naming rules.

There is no installer-specific public host metadata output and no
installer-only runtime-context/default-target abstraction.

## Facter-only final configurations

`nixos-facter` is the sole hardware-description mechanism for final NixOS
configurations.

A NixOS host with:

```text
nix/profiles/hosts/<host>/facter.json
```

exports its final `nixosConfigurations`.

A declared NixOS host without that file:

- still gets `packages.installer-<host>`;
- does not export final `nixosConfigurations` yet.

This permits a newly declared host to bootstrap without making
`nix flake check` unhealthy.

When a final configuration is exported it declares:

```nix
hardware.facter.reportPath = ./facter.json;
```

There is no fallback to `hardware-configuration.nix`.

The user's existing legacy host migration is outside this implementation and
must be completed before removing its old import on the live branch.

## Installation-time hardware facts

The ISO embeds the immutable filtered dotfiles snapshot.

At runtime the installer:

1. copies that store snapshot to writable
   `/run/dotfiles-installer/source`;
2. generates
   `nix/profiles/hosts/<host>/facter.json` directly into the writable copy;
3. evaluates the resulting filesystem tree with explicit `path:` flake
   semantics.

No Git commit is created. Git history has no role.

## Frozen dependencies

Installation MUST NOT update dependency selection.

Every installer-side Nix command consuming the writable snapshot uses:

```text
--no-update-lock-file
```

The installer does not pass `--no-write-lock-file` and never runs
`nix flake update`.

If evaluation would require a lock change, it fails before destructive work.

Missing already-locked inputs, substitutes, and build dependencies may be
fetched from the network.

`nix run path:.#update` remains the workflow that intentionally changes
`flake.lock`.

## Fixed storage topology

The first implementation has one storage layout:

```text
GPT
├── ESP               -> /boot
└── dotfiles-system   -> Btrfs
    ├── @root         -> /
    ├── @nix          -> /nix
    └── @persist      -> /persist
```

The constants are:

```text
install target alias = /dev/dotfiles-install-target
system PARTLABEL     = dotfiles-system
root subvolume       = @root
nix subvolume        = @nix
persist subvolume    = @persist
```

Disko solely owns partitioning, filesystem creation, subvolume creation, and
mount definitions.

There is no public storage-device option, filesystem UUID identity,
configurable partition label, configurable subvolume name, or provisioning
enable flag.

Attaching another installed dotfiles disk with `PARTLABEL=dotfiles-system` is
outside the supported boot environment. Initrd root-reset logic nevertheless
fails closed unless exactly one matching partition exists.

## Impermanence

Impermanence owns root reset and persistence policy, not storage topology.

The root-reset implementation is internal to the impermanence feature. It:

- finds exactly one `PARTLABEL=dotfiles-system` partition in initrd;
- mounts the Btrfs top level temporarily;
- deletes existing `@root`;
- recreates `@root` before `sysroot.mount`;
- marks `/nix` and `/persist` needed for boot;
- enables the repository's narrow preservation policy.

There is no separately configurable public `ephemeralRoot` interface.

## Authentication

The final NixOS configuration declares directly:

```nix
users.mutableUsers = false;
users.users.<primary>.hashedPasswordFile =
  "/persist/etc/dotfiles/password-<primary>.hash";
```

SSH authorized keys remain dotfiles state.

There is no bootstrap-credentials wrapper module or duplicate hash-path option.

The installer:

1. prompts twice;
2. rejects empty or mismatched input;
3. hashes the password with yescrypt in RAM;
4. discards plaintext;
5. evaluates the final configuration;
6. reads the authoritative `hashedPasswordFile`, home, UID, primary group,
   and GID;
7. after Disko mounts `/persist`, writes only the hash to
   `/mnt + hashedPasswordFile` with restrictive permissions.

Secret material never enters the source snapshot or Nix store.

## Installer runtime closure

The installer script is self-contained. It references required executables by
their Nix store paths rather than relying on ambient packages from the minimal
ISO.

At minimum the closure explicitly provides:

- Nushell;
- nixos-facter;
- Nix;
- nixos-install;
- mkpasswd;
- util-linux tools;
- coreutils;
- systemd tools.

Git is not an installer runtime dependency.

## Installer console

The installer owns `/dev/tty1` exclusively.

The minimal ISO's initial tty1 getty is removed, and the tty1 getty/autovt
instances are masked so logind cannot recreate them on VT switching.

A second virtual console remains available for diagnostics.

The installer service uses `Type=exec`, so it is active while the
long-running interactive transaction is waiting for password input.

The console contract is:

```text
tty1 -> dotfiles-installer.service only
tty2 -> diagnostic getty
```

Switching tty1 -> tty2 -> tty1 must not displace the installer.

## Destructive acceptance barrier

All installer preparation before disk modification is reversible.

Immediately before creating `/dev/dotfiles-install-target` and invoking Disko,
the installer performs one disk check:

```text
lsblk --json --output PATH,TYPE,RM,HOTPLUG
```

Exactly one whole disk must satisfy:

```text
TYPE = disk
RM = 0
HOTPLUG = 0
```

If zero or multiple disks qualify, installation exits with storage untouched.

There is no earlier disk preflight and no cross-time disk identity.

There is no Git/remote acceptance check because source history is out of scope;
the source has already been frozen as the embedded Nix store snapshot.

## Installation transaction

The transaction is:

```text
boot ISO
↓
copy embedded filtered snapshot
  -> /run/dotfiles-installer/source
↓
make writable
↓
prompt/hash administrator password
↓
generate facter.json into writable source
↓
evaluate path:/run/dotfiles-installer/source#<target>
  --no-update-lock-file
↓
resolve hashedPasswordFile / home / UID / primary group / GID
↓
realize Disko script
  --no-update-lock-file
↓
──────── final destructive acceptance barrier ────────
exactly one eligible internal whole disk
──────────────────────────────────────────────────────
↓
/dev/dotfiles-install-target -> selected disk
↓
Disko provisions fixed GPT + ESP + Btrfs topology
↓
write persistent password hash
↓
nixos-install --root /mnt
  --flake path:/run/dotfiles-installer/source#<target>
  --no-update-lock-file
↓
verify /mnt/boot/EFI/BOOT/BOOT<ARCH>.EFI
↓
copy writable dotfiles snapshot
  -> /mnt/persist + <evaluated home> + /dotfiles
↓
chown dotfiles using evaluated UID/GID
↓
sync
↓
unmount /mnt recursively
↓
power off
```

The final system and persisted dotfiles are derived from the same filesystem
snapshot plus freshly generated facter data.

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

The complete final closure is not realized before the destructive barrier and
does not need to fit in the live ISO store.

## Persistent dotfiles

The installer copies the writable source tree to:

```text
/mnt/persist + <evaluated primary home> + /dotfiles
```

and assigns the evaluated UID/GID.

The installed dotfiles directory is a plain filesystem snapshot. It contains no
required Git metadata and makes no promise about branch, remote, or history.

## Update workflow without Git metadata

The existing update transaction remains responsible for:

- copying the current dotfiles source to a temporary candidate;
- running `nix flake update` on that candidate;
- validating target evaluations;
- publishing the new `flake.lock`;
- activating validated targets.

Its operation lock must not depend on a Git common directory.

Use a repository-local transient lock directory:

```text
<dotfiles>/.dotfiles-update.lock
```

and include that path in the source-ignore policy so it never enters an
installer/update snapshot.

Concurrency guarantees are scoped to one dotfiles directory. Cross-copy Git
worktree coordination is no longer part of the contract.

The update app also consumes the same filtered dotfiles snapshot policy.

## Testing strategy

Keep four complementary levels of coverage.

### Structural/unit checks

`nix flake check path:.` covers:

- source filtering includes ordinary current files and excludes ignore-policy
  files;
- installer packages exist for declared NixOS hosts even without facter;
- final NixOS configurations are exported only when facter exists;
- fixed Disko topology;
- direct persistent password policy;
- root-reset unit structure and duplicate-PARTLABEL failure logic;
- disk selector zero/one/multiple behavior;
- frozen-lock rejection;
- explicit installer runtime executable closure;
- tty1 masks and `Type=exec`;
- Git-independent update locking.

Because tests use explicit `path:.`, newly created implementation files are
visible before they are committed.

### Deterministic impermanence VM

Keep one small deterministic boot/reboot VM test that proves the storage/root
reset contract without involving ISO, networking, facter generation, or
installer interaction.

It verifies:

```text
fixed Disko layout
→ boot
→ create disposable + preserved state
→ reboot
→ @root recreated
→ persistent state survives
```

Other historical intermediate VM layers are removed.

### Installer lifecycle E2E

A dedicated test:

```text
nix run path:.#test-installer-e2e
```

boots the actual generated ISO and verifies:

1. tty1 remains installer-owned across tty1 -> tty2 -> tty1 switching;
2. embedded filtered snapshot is copied to writable runtime state;
3. fresh facter is generated;
4. final target evaluates from the writable `path:` snapshot;
5. the final single-disk barrier succeeds;
6. Disko provisions the fixed topology;
7. target-store `nixos-install` succeeds;
8. fallback EFI loader exists;
9. persisted dotfiles and password hash have correct ownership/placement;
10. installer powers off;
11. installed disk boots after installer media removal;
12. password login and sudo work;
13. impermanent root resets while persistent state survives.

The E2E may require network access for locked Nix dependencies, but it does not
contact a Git repository or require a public commit.

### Update regression

The existing update tests are converted to ordinary directories rather than Git
repositories. They continue to prove candidate isolation, failure behavior,
activation ordering, and single-directory mutual exclusion.

## Non-goals

The installer does not support or reason about:

- Git commits or history;
- branches or detached HEAD;
- Git remotes;
- staging/index state;
- tracked versus untracked files;
- source publication to a remote;
- preserving Git metadata in installed dotfiles;
- choosing theme/session/account at installer-build time;
- multiple eligible internal disks;
- target-disk overrides;
- configurable partition labels or subvolume names;
- attaching multiple installed dotfiles disks at boot;
- preserving target data on reinstall;
- offline guarantees;
- installer media that looks like an eligible internal disk;
- `hardware-configuration.nix` fallback;
- filesystem UUID identity;
- EFI-variable writes;
- automatic firmware handoff;
- kexec;
- dependency updates during installation.

## Completion invariants

Implementation is complete when:

1. `nix run path:.#build-installer -- --host HOST` works generically;
2. the ISO embeds the exact filtered current dotfiles snapshot;
3. Git metadata/history is absent from installer source identity and runtime;
4. ignored local state is excluded from the embedded snapshot;
5. facter-less declared NixOS hosts have installer packages but no final
   `nixosConfigurations`;
6. generated facter makes the final configuration appear in the writable
   runtime snapshot;
7. every installer-side flake evaluation/build/install uses
   `--no-update-lock-file`;
8. the final destructive barrier contains only the exactly-one-disk check;
9. Disko alone owns the fixed storage topology;
10. initrd root reset fails closed unless exactly one `dotfiles-system`
    partition exists;
11. password policy is declared directly in the final NixOS configuration;
12. installer runtime dependencies are explicit Nix store references;
13. tty1 remains exclusively installer-owned during interaction;
14. systemd-boot fallback boot works without EFI-variable writes;
15. successful installation ends with sync, unmount, and poweroff;
16. persisted dotfiles work without Git metadata;
17. `path:.#update` no longer requires a Git working tree;
18. structural checks, one deterministic impermanence VM, and one lifecycle E2E
    cover the supported contract.
