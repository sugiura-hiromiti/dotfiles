# NixOS Impermanence Bootstrap and Installer Design

Date: 2026-09-18
Revised: 2026-09-19

## Status

Approved design, revised after implementation-plan review.

## Purpose

Complete the NixOS impermanence implementation so storage layout, hardware
discovery, installation, authentication, boot handoff, and steady-state updates
have clear ownership and do not depend on remembered manual procedures.

The design separates machine creation/recreation from daily configuration
updates:

- a host-specific installer ISO creates or recreates a machine;
- `nix run .#update` evolves an already managed machine.

## Nix boundary

The complete workflow is Nix-managed, but not every operation is a pure Nix
expression.

Nix owns:

- installer ISO construction;
- the exact Git revision and `flake.lock` used by the installer;
- packages and scripts used by the installer;
- systemd service ordering and failure behavior;
- NixOS user/authentication policy;
- Disko storage topology;
- preservation and impermanence policy;
- tests for the installation lifecycle.

Runtime installer code built by Nix performs operations that inherently require
the live machine:

- hardware discovery;
- interactive secret entry;
- disk discovery;
- destructive formatting;
- writing runtime secret material outside the Nix store;
- UEFI boot handoff and reboot/kexec.

Runtime behavior MUST NOT introduce a second configuration model independent of
Nix.

## Goals

1. Make the dotfiles repository at installer-build time the declarative source
   of truth.
2. Freeze dependency selection at installer-build time through the committed
   `flake.lock`.
3. Remove generated `hardware-configuration.nix` filesystem declarations from
   the storage ownership model.
4. Store discovered non-secret hardware facts in the repository.
5. Give Disko sole ownership of installed disk/filesystem topology.
6. Give impermanence sole ownership of ephemeral-root lifecycle behavior.
7. Automate installation except for deliberate secret entry.
8. Make destructive behavior fail-closed and safe against accidental installer
   re-entry.
9. Ensure the primary administrator can log in locally and use sudo immediately
   after the first installed boot without running `passwd`.
10. Keep `.#update` non-destructive and separate from installation.
11. Preserve the existing narrow persistence policy.
12. Test lower-level storage/impermanence behavior, the real production profile,
    and the complete installer lifecycle.

## Non-goals

- Preserving data from an existing target installation during reinstall.
- Recovering unpushed commits or other state from the old target disk.
- Updating flake inputs during installation.
- Making GitHub the authoritative source at installation time.
- Automatically pushing installer-created commits.
- Storing password hashes or other secrets in Git or the Nix store.
- Folding destructive bootstrap behavior into `.#update`.

## Source-of-truth model

The source of truth for an installer image is the clean committed dotfiles
repository on the machine that builds that image.

A host-specific ISO is a deployment artifact derived from:

- one exact Git `HEAD`;
- the `flake.lock` committed at that `HEAD`;
- host identity and installer policy from that repository.

Installation MUST NOT run `nix flake update`.

Every installer-side Nix command that consumes the installation flake MUST pass
both `--no-update-lock-file` and `--no-write-lock-file`. The first forbids
Nix from resolving a graph that would require lock changes; the second forbids
writing any generated lock state. A required lock change is therefore a hard
pre-destructive failure.

The installer may fetch locked Nix inputs or substitutes when they are not
already available, but it MUST use exactly the dependency graph described by
the embedded `flake.lock`.

Therefore:

```text
clean Git HEAD + flake.lock
          ↓
      host ISO
          ↓
generate facter.json
          ↓
evaluate final configuration
          ↓
      Disko target
          ↓
nixos-install realizes the final closure
directly into the target /nix store
```

The installer may use the network to fetch locked flake inputs, substitutes, and
build dependencies. Network availability does not permit dependency selection
to change: the embedded `flake.lock` remains authoritative.

### Clean-tree and Git-provenance invariant

A host ISO MUST be built only from a clean Git worktree that is attached to an
explicit local branch and has a canonical `origin` URL.

The ISO builder MUST fail when:

- tracked, staged, or untracked state would make the artifact differ from the
  committed revision it claims to represent;
- `HEAD` is detached;
- the current branch cannot be named;
- the canonical `origin` URL is absent.

The builder embeds:

- the exact committed `HEAD`;
- the explicit current branch ref, not anonymous `HEAD` only;
- the canonical `origin` URL.

The installer clones that branch from the bundle, restores `origin` to the
canonical URL, and verifies branch/HEAD before generating installer state. The
persisted checkout therefore has a normal branch/remote relationship.

## Host lifecycle

A host has two valid declarative phases.

### Bootstrap-capable host

Static repository state is sufficient to build an installer ISO:

- host identity;
- architecture/system;
- users/accounts;
- roles/variants;
- runtime policy;
- impermanence/storage policy;
- target-disk selector;
- installer policy.

Hardware facts may be absent.

### Resolved host

The bootstrap-capable host plus `facter.json` is sufficient to evaluate the
final installed NixOS configuration.

Representative layout:

```text
nix/profiles/hosts/<host>/
├── meta.nix
├── nixos.nix
└── facter.json
```

`facter.json` may be absent before first installation.

## Hardware ownership

`nixos-facter` owns observed hardware facts.

The installer regenerates the host's `facter.json` on every installation.
Hardware facts are observed non-secret state and are committed locally to the
embedded dotfiles Git history.

The final host configuration uses:

```nix
hardware.facter.reportPath = ./facter.json;
```

rather than generated `hardware-configuration.nix`.

A legacy `hardware-configuration.nix` may remain temporarily as a migration
fallback for the currently running pre-bootstrap installation, but it is not
the final storage/hardware ownership model.

The bootstrap ISO must evaluate without `facter.json`; the final target must
be evaluated only after facts have been generated.

## Storage ownership

Disko is the only owner of the installed storage topology.

Target layout:

- GPT;
- EFI System Partition mounted at `/boot`;
- Btrfs system filesystem;
- `@root` mounted at `/`;
- `@nix` mounted at `/nix`;
- `@persist` mounted at `/persist`.

The final NixOS `fileSystems` definitions come from Disko, not generated
hardware configuration.

The current design keeps a deterministic host-derived Btrfs filesystem UUID.
Because an old clone of the same host can carry the same UUID, uniqueness is a
required safety invariant:

- before Disko, any matching filesystem on a non-target attached device aborts
  installation;
- a matching filesystem on the selected target may be replaced by reinstall;
- at boot/initrd time, the configured UUID must resolve to exactly one block
  filesystem or boot fails closed before ephemeral-root mutation.

The physical disk is chosen at runtime. Nix evaluation refers to a fixed logical
device path such as `/dev/dotfiles-install-target`; the installer creates that
symlink only after safe target-identity proof.

## Impermanence ownership

Impermanence owns runtime ephemeral-root behavior, not partitioning.

When enabled it:

- enables ephemeral root;
- uses the storage module's Btrfs device/root subvolume;
- marks `/nix` and `/persist` needed for boot;
- relies on preservation for the explicit persistence set.

The current initrd behavior that deletes and recreates the root subvolume before
mounting the real root remains the reset mechanism.

## Authentication model

The primary administrator password is chosen interactively during installation.

Nix declares the policy:

- the primary account has a `hashedPasswordFile` under `/persist`;
- user state is immutable/declarative with `users.mutableUsers = false`;
- SSH authorized keys remain declared in repository metadata;
- the password hash file is outside Git and outside the Nix store.

The installer performs only secret materialization:

1. prompt for the password twice before destructive work;
2. reject mismatch/empty input;
3. hash the password in installer RAM;
4. keep plaintext only in memory for the shortest possible duration;
5. after `/persist` exists, write exactly the hash to the configured persistent
   path with restrictive permissions.

After installation and after every ephemeral-root reconstruction, NixOS
activation reads the same persistent hash file. The administrator does not need
to run `passwd` after installation.

The installed-system test MUST prove both local password authentication and
successful sudo authentication using that password in the test fixture.

## Installer artifact

There is one custom installer ISO per host.

The ISO carries:

- host identity;
- exact clean Git repository history from the build machine;
- the committed `flake.lock`;
- Nix-built installer tooling;
- a unique installer artifact ID used only for destructive re-entry safety.

The artifact ID is safety metadata, not configuration state.

The ISO explicitly enables:

```nix
nix.settings.experimental-features = [
  "nix-command"
  "flakes"
];
```

No per-command experimental-feature flag is required.

The ISO does not need to contain the complete final closure; installation may
fetch objects addressed by the existing lock file.

## Target-disk identity and selection policy

A destructive target is a physical-disk identity, not a kernel device pathname.

Host metadata may specify:

```nix
installer.disk.byId = "/dev/disk/by-id/...";
```

The configured value MUST identify a whole disk through `/dev/disk/by-id/`.
Persistent overrides using enumeration paths such as `/dev/sda`,
`/dev/vda`, or `/dev/nvme0n1` are rejected.

Without an explicit `byId`, automatic selection is:

> the only internal, non-removable, non-hotplug whole disk that is not the live
> installer backing disk.

Selection is fail-closed:

- one candidate: select it;
- zero: abort;
- multiple: abort unless host metadata supplies `installer.disk.byId`.

At initial selection the installer captures an identity snapshot containing:

- configured/discovered stable by-id path when available;
- resolved device node;
- sysfs device path;
- major:minor device number;
- serial/WWN when exposed.

Immediately before Disko it resolves the stable identifier again when one
exists and proves the selected disk still matches the captured sysfs and
major:minor identity. In the automatic one-disk case it repeats candidate
discovery and proves the sole candidate is the same captured device. Merely
proving that the old `/dev/sdX` pathname is still a valid disk is insufficient.

The live installer medium is derived independently for the current boot:
resolve the block source backing the mounted live ISO, walk block-device
ancestry to its unique whole-disk or optical ancestor, and capture its
sysfs/major:minor identity. If the live medium cannot be reduced to one
trustworthy backing identity, destructive installation aborts.

The selected physical device is linked to `/dev/dotfiles-install-target` only
after this identity proof succeeds.

## Installation semantics

Booting the host-specific ISO means:

> create/recreate this host from the exact repository and dependency lock
> represented by this installer.

A deliberate reinstall wipes the target disk completely. Existing `/persist`,
old Git state, and other target state are not merged.

The installer transaction is:

1. start from the clean repository embedded in the ISO;
2. identify the host from the ISO;
3. resolve the intended target disk using static host policy;
4. inspect that disk for the same installer artifact's completion marker;
5. if the same marker exists, skip all reinstall/password work and immediately
   repair/verify boot handoff to the installed system;
6. otherwise prompt for and hash the primary administrator password;
7. regenerate and stage `facter.json`;
8. evaluate the complete final target configuration using the embedded
   `flake.lock`, without realizing the full system closure;
9. evaluate the resolved primary user's home directory, password-hash path,
   UID, primary group, and that group's GID from the final configuration;
10. realize the comparatively small Disko provisioning script required for the
    destructive step;
11. if staged `facter.json` differs from embedded `HEAD`, commit it; if facts
    are unchanged, continue from the embedded commit without creating an empty
    commit;
12. reject any non-target attached filesystem that already carries the
    deterministic host Btrfs UUID;
13. revalidate immediately before destruction that the selected physical-disk
    identity is unchanged and differs from the captured installer-medium
    identity;
14. create `/dev/dotfiles-install-target`;
15. run Disko, wiping/recreating the target and mounting it below `/mnt`;
16. materialize the password hash under the mounted target `/persist`;
17. run `nixos-install --root /mnt --flake ... --no-update-lock-file
    --no-write-lock-file`; it fetches/builds as needed and realizes the final
    system directly into the target store at `/mnt/nix/store`;
18. copy the Git checkout to the persistent backing path corresponding to the
    resolved user home and chown it using the evaluated UID/GID;
19. write the installer completion marker to the target ESP;
20. durably flush the marker and ESP before attempting boot handoff;
21. derive and verify the target ESP/loader, create/find the installed UEFI boot
    entry, make it first in persistent `BootOrder`, set it as `BootNext`,
    and verify both settings;
22. sync and unmount the target filesystems;
23. reboot once into the installed system, or use the defined safe fallback
    when verified UEFI handoff is unavailable.

The installer MUST NOT modify `flake.lock` and MUST NOT push Git state.

## Boot handoff and destructive re-entry safety

Automatic reboot must not allow firmware that prefers USB/CD to start another
destructive installation.

Safety uses two layers.

### Firmware/runtime handoff

The installer does not rely on `boot.loader.efi.canTouchEfiVariables`; the
installed system may keep that option false. The installer owns this one-time
handoff operation explicitly.

Before changing NVRAM it MUST prove:

- the target is booted in UEFI mode and efivarfs is present and writable;
- the ESP is exactly the EFI System Partition belonging to the already-proven
  target physical disk;
- its partition number is known;
- an architecture-matching installed EFI loader exists on that ESP;
- the loader path used for the firmware entry is the path actually present on
  the target ESP, not a guessed pathname.

The normal UEFI path then:

1. creates or locates the firmware entry using the proven target disk, ESP
   partition number, and installed loader path;
2. places that entry first in persistent `BootOrder`;
3. sets the same entry as one-shot `BootNext`;
4. reads NVRAM back and verifies both values before reboot.

A Nix-built kexec handoff may be used as a fallback for the immediate first boot
when verified UEFI handoff is unavailable. The installer does not perform an
unsafe blind reboot.

### Re-entry guard

The ISO carries a unique installer artifact ID.

After successful `nixos-install`, the target stores a marker containing that
installer ID on the ESP. The marker is flushed durably before any boot-handoff
operation begins.

If the same ISO boots again and finds its completion marker on the selected
target, it MUST NOT run Disko. Instead it automatically attempts the installed
system handoff again by repairing/verifying persistent boot priority and
`BootNext`, then rebooting or using the safe fallback.

A newly built ISO has a new installer artifact ID and may deliberately reinstall
the host.

This makes repeated boot of the same attached installation medium safe without
requiring manual removal for correctness. Persistent `BootOrder` prevents
ordinary later reboots from returning to the ISO in normal firmware behavior;
the marker-driven handoff path covers firmware that still starts the ISO.

## Target store lifecycle

During installation, `/mnt` is only the live installer's mount point for the
future installed root. With the Disko layout:

```text
/mnt          -> future /
/mnt/nix      -> future /nix
/mnt/persist  -> future /persist
/mnt/boot     -> future /boot
```

Therefore `/mnt/nix/store` is not temporary scratch space. It is the future
installed `/nix/store`. `nixos-install --root /mnt` realizes/fetches the
large final closure into that target store after Disko has created it.

The installer MUST NOT wipe `/mnt` after installation. It only syncs and
unmounts the target before reboot; the same filesystems are mounted at their
normal paths by the installed system.

This avoids requiring the live ISO's writable store/RAM to hold the full final
system closure before formatting.

## Persistent checkout path

The installer MUST NOT assume `/home/<user>`.

It evaluates the resolved final NixOS account values:

```text
config.users.users.<primary>.home
config.users.users.<primary>.uid
config.users.users.<primary>.group
config.users.groups.<resolved-group>.gid
```

and places the repository in the corresponding persistent backing path:

```text
/mnt/persist + resolved-home + /dotfiles
```

This matches preservation's use of the resolved NixOS user home and avoids
duplicating account policy in installer code. Ownership is applied with the
evaluated UID/GID rather than reconstructed from metadata.

## Installer-generated Git state

The installer starts from the exact embedded branch at the exact embedded Git
commit, with `origin` restored to the canonical build-time remote URL.

Its only permitted repository mutation is the generated host `facter.json`.

If regenerated facts differ from embedded `HEAD`, the installer creates one
local facter commit. If the regenerated file is byte-for-byte unchanged, the
installer creates no commit and continues from embedded `HEAD`.

Any installer-created facter commit does not need to exist on a remote.

A local branch ahead of its remote is valid and MUST NOT prevent `.#update`
from working.

Pushing remains synchronization/backup, not a prerequisite for machine
management.

## Steady-state update path

`nix run .#update` remains the only dependency-update path.

Its responsibilities remain:

1. create a candidate source tree;
2. update flake inputs;
3. evaluate selected targets;
4. authorize where necessary;
5. publish the resulting `flake.lock`;
6. activate Home Manager/NixOS/nix-darwin targets.

For NixOS activation it continues to use `nixos-rebuild switch`.

The installer never takes over these responsibilities.

## Safety model

Before Disko is allowed to run, all of the following must have succeeded:

- host identity is known from the ISO;
- embedded repository state is valid;
- password entry succeeded and only its in-memory hash remains;
- hardware discovery succeeded;
- `facter.json` exists;
- every Nix flake operation forbids lock updates and lock writes;
- final target evaluation succeeded using the embedded lock;
- resolved administrator home/password/UID/GID values were obtained from the
  final configuration;
- the Disko provisioning script was realized successfully;
- target disk selection resolved one intended physical-disk identity;
- the selected identity is unchanged at final revalidation;
- live installer medium identity was derived unambiguously and differs from the
  target;
- no non-target attached filesystem duplicates the configured Btrfs UUID;
- same-installer re-entry protection says destructive installation is allowed.

Any ambiguity is an error. No destructive action is a fallback.

## Testing strategy

### Existing lower-level tests

Retain and extend:

- preservation;
- ephemeral-root;
- impermanence evaluation;
- storage provisioning evaluation;
- storage provisioning VM;
- impermanence VM.

### Hardware/source tests

Prove:

- bootstrap ISO evaluates without facts;
- final target consumes facter facts;
- facter takes precedence over legacy hardware configuration;
- hardware facts do not own filesystem topology.

### Authentication tests

Prove:

- Nix declares the primary user's persistent `hashedPasswordFile`;
- mutable user state is disabled;
- installer secret input never enters Git/store fixtures;
- after installed boot, the configured password works;
- administrative sudo works in the test fixture;
- the same authentication survives an ephemeral-root reboot.

### Production migration test

Do not skip the real host merely because it is currently legacy.

Construct a temporary target using the actual `aarch64-linux-a` host/profile
metadata and module composition, override only hardware state with fixture
`facter.json`, then evaluate all production runtime targets.

Assert Disko/facter/impermanence ownership there before real rollout.

### Installer end-to-end VM

The full installer lifecycle is a dedicated networked integration test rather
than an ordinary sandboxed `nix flake check` derivation.

The test definition/driver is still built by Nix, but QEMU/test-driver execution
runs outside the Nix build sandbox and may assume network access, matching the
production installer's allowed behavior. The installer uses the real embedded
`flake.lock`; it never runs `flake update`.

Run real:

- final Nix evaluation;
- network fetch/substitution/build after Disko;
- Disko;
- `nixos-install`;
- preservation;
- ephemeral-root behavior;
- UEFI handoff/re-entry behavior.

Hardware probing may be replaced by a deterministic test facter generator.

The networked test must:

1. boot the installer ISO;
2. supply a test password through the installer interaction path;
3. generate hardware facts;
4. evaluate the final target before wipe;
5. install to a blank disk;
6. prove the final closure is realized under the target `/mnt/nix/store`, not
   as a required full pre-format closure in the live installer store;
7. leave the installer ISO attached;
8. exercise the installer's automatic handoff/reboot rather than manually
   switching VM state;
9. prove the installed system boots;
10. prove Disko was not executed twice;
11. verify Btrfs `@root`, `@nix`, `@persist`;
12. verify persisted/disposable state across another reboot;
13. verify administrator authentication/sudo;
14. verify changed facts produce a local facter commit and unchanged facts do
    not require an empty commit;
15. verify a custom-home fixture places the checkout under the correct
    persistent backing path;
16. force the same ISO to boot again and prove it automatically hands off
    without formatting;
17. swap kernel device-node assignments between selection and final validation
    and prove the physical target identity is preserved or the installer aborts
    before Disko;
18. prove an unstable configured path such as `/dev/sdb` is rejected;
19. prove a flake requiring a lock mutation fails under
    `--no-update-lock-file`;
20. attach a non-target filesystem with the same deterministic Btrfs UUID and
    prove installation aborts;
21. verify the persisted Git checkout is on the embedded branch and its
    `origin` is the canonical remote;
22. prove ESP/partition/loader/NVRAM handoff inputs are derived from the selected
    target and persistent NVRAM survives reboot.

Add negative tests for zero/multiple target disks.

Deterministic module/unit/production-evaluation tests remain in
`nix flake check`; Internet-dependent lifecycle execution does not.

## Build output hygiene

The installer result symlink lives under the repository's already ignored
`result/` directory, for example:

```text
result/installer-aarch64-linux-a
```

A successful installer build therefore does not make the clean-tree check fail
on the next invocation.

## Migration from current repository

1. model bootstrap/facter state in host metadata;
2. centralize facter-vs-legacy hardware selection;
3. make Disko available in production NixOS construction;
4. add persistent administrator credential policy;
5. add disk selection;
6. add installer transaction without `flake update`;
7. add re-entry protection and automatic boot handoff;
8. add host-specific ISO construction;
9. add clean-tree installer build app;
10. add real-host-with-fixture-facts migration coverage;
11. add dedicated networked full-lifecycle installer VM coverage;
12. gate the real host's Btrfs/impermanence policy on facter migration;
13. only then perform destructive real-machine rollout.

## Design invariants

Implementation is complete when:

1. a host ISO builds from clean committed state without `facter.json`;
2. installer dependency selection is exactly the embedded `flake.lock`, and
   any operation requiring lock mutation fails;
3. installation never runs `nix flake update`;
4. the user chooses the administrator password during installation and never
   needs a post-install `passwd` step;
5. the password hash remains outside Git and the Nix store;
6. final target evaluation occurs only after hardware facts exist;
7. the full final closure is realized only after Disko creates the target
   `/nix` store;
8. only changed `facter.json` may be committed by the installer;
9. Disko is the sole filesystem topology owner;
10. impermanence owns only runtime root reset;
11. destructive selection follows stable physical-disk identity, never a
    persistent `/dev/sdX`-style name;
12. the live installer medium is identified unambiguously and cannot be the
    destructive target;
13. the host-derived Btrfs UUID is unique among attached non-target filesystems,
    and initrd boot fails closed if it is ambiguous;
14. the completion marker is durably stored before boot handoff begins;
15. persistent boot priority favors the installed disk, and same-ISO re-entry
    automatically hands off without formatting;
16. the installed checkout is on the build-time branch with the canonical
    `origin`, and installer facter commits may leave it ahead of that remote;
17. installer result links do not dirty the repository;
18. repository persistence and ownership follow resolved NixOS home/UID/GID
    values;
19. `.#update` remains the steady-state dependency-update/activation path;
20. tests exercise lower-level mechanisms, destructive identity falsification,
    the actual production profile with fixture facts, and the complete
    networked installer lifecycle.
