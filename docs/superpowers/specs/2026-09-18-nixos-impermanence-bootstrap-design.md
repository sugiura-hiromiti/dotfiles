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

The installer may fetch locked Nix inputs or substitutes when they are not
already available, but it MUST use the dependency graph described by the
embedded `flake.lock`.

Therefore:

```text
clean Git HEAD + flake.lock
          ↓
      host ISO
          ↓
generate facter.json only
          ↓
evaluate/build with same flake.lock
          ↓
install
```

### Clean-tree invariant

A host ISO MUST be built only from a clean Git worktree.

The ISO builder MUST fail when tracked, staged, or untracked state would make
the artifact differ from the committed revision it claims to represent.

The embedded repository starts installation clean and at a known commit.

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

The physical disk is chosen at runtime. Nix evaluation refers to a fixed logical
device path such as `/dev/dotfiles-install-target`; the installer creates that
symlink only after safe target selection.

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

The installed-system test MUST prove both local password authentication policy
and non-interactive ability to obtain administrator privileges in the test
fixture.

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

## Target-disk policy

Default target selection is:

> the only internal, non-removable, non-hotplug whole disk that is not the live
> installer backing disk.

Selection is fail-closed:

- one candidate: select it;
- zero: abort;
- multiple: abort unless host metadata supplies an explicit override.

An explicit override is canonicalized before comparison and must resolve to a
whole disk that is not the installer medium.

The selected physical device is linked to the logical Disko device only after
all non-destructive preflight checks have succeeded.

## Installation semantics

Booting the host-specific ISO means:

> create/recreate this host from the exact repository and dependency lock
> represented by this installer.

A deliberate reinstall wipes the target disk completely. Existing `/persist`,
old Git state, and other target state are not merged.

The installer transaction is:

1. start from the clean repository embedded in the ISO;
2. identify the host from the ISO;
3. prompt for and hash the primary administrator password;
4. regenerate `facter.json`;
5. stage `facter.json`;
6. evaluate/build the complete target configuration using the embedded
   `flake.lock`;
7. evaluate the resolved primary user's home directory and password-hash path
   from the final NixOS configuration;
8. build the Disko provisioning script;
9. commit only `facter.json` as installer-generated Git state;
10. resolve exactly one safe target disk;
11. check destructive re-entry guards before touching the disk;
12. create `/dev/dotfiles-install-target`;
13. run Disko, wiping/recreating the target;
14. materialize the password hash under `/persist`;
15. install the already-built NixOS system;
16. copy the modified Git checkout to the persistent backing path corresponding
    to the resolved user home;
17. establish and verify automatic boot handoff;
18. record handoff/re-entry safety state;
19. reboot or kexec only after the handoff state is safe.

The installer MUST NOT modify `flake.lock` and MUST NOT push Git state.

## Boot handoff and destructive re-entry safety

Automatic reboot must not allow firmware that prefers USB/CD to start another
destructive installation.

Safety uses two layers.

### Firmware/runtime handoff

The installer attempts an automatic handoff to the installed system using UEFI
boot variables/one-shot boot selection where available. A Nix-built kexec
handoff may be used as a fallback for the immediate first boot.

The installer verifies a handoff mechanism before issuing an ordinary reboot.

### Re-entry guard

The ISO carries a unique installer artifact ID.

After successful provisioning/install, the target stores a marker containing
that installer ID on persistent boot-visible storage.

If the same ISO boots again and finds its completion/pending marker on the
selected target, it MUST refuse to run Disko again.

A newly built ISO has a new installer artifact ID and may deliberately reinstall
the host.

This makes repeated boot of the same attached installation medium safe without
requiring manual removal for correctness.

## Persistent checkout path

The installer MUST NOT assume `/home/<user>`.

It evaluates the resolved final NixOS value:

```text
config.users.users.<primary>.home
```

and places the repository in the corresponding persistent backing path:

```text
/mnt/persist + resolved-home + /dotfiles
```

This matches preservation's use of the resolved NixOS user home and avoids
duplicating home-directory policy in installer code.

## Installer-generated Git state

The installer starts from a clean embedded Git commit.

Its only repository mutation is the generated host `facter.json`.

The installer commit does not need to exist on a remote.

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
- final target evaluation/build succeeded using the embedded lock;
- resolved administrator home/password paths were obtained from the final
  configuration;
- Disko script build succeeded;
- target disk selection resolved exactly one permitted whole disk;
- live installer medium exclusion succeeded;
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

The VM test must be network-independent.

Use a fixture repository whose locked inputs point to local/store-backed source
fixtures and ensure required source/build closures are dependencies of the test.

Run real:

- final Nix evaluation/build;
- Disko;
- `nixos-install`;
- preservation;
- ephemeral-root behavior.

Hardware probing may be replaced by a deterministic test facter generator.

The test must:

1. boot the installer ISO;
2. supply a test password through the installer interaction path;
3. generate hardware facts;
4. build from the existing lock without `flake update`;
5. install to a blank disk;
6. leave the installer ISO attached;
7. exercise the installer's automatic handoff/reboot rather than manually
   switching VM state;
8. prove the installed system boots;
9. prove Disko was not executed twice;
10. verify Btrfs `@root`, `@nix`, `@persist`;
11. verify persisted/disposable state across another reboot;
12. verify administrator authentication/sudo;
13. verify the installed repository contains the facter commit;
14. verify a custom-home fixture places the checkout under the correct persistent
    backing path.

Add negative tests for zero/multiple target disks and same-ISO destructive
re-entry.

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
11. add offline full-lifecycle installer VM coverage;
12. gate the real host's Btrfs/impermanence policy on facter migration;
13. only then perform destructive real-machine rollout.

## Design invariants

Implementation is complete when:

1. a host ISO builds from clean committed state without `facter.json`;
2. installer dependency selection is exactly the embedded `flake.lock`;
3. installation never runs `nix flake update`;
4. the user chooses the administrator password during installation and never
   needs a post-install `passwd` step;
5. the password hash remains outside Git and the Nix store;
6. final target evaluation occurs only after hardware facts exist;
7. only `facter.json` is committed by the installer;
8. Disko is the sole filesystem topology owner;
9. impermanence owns only runtime root reset;
10. target selection fails closed;
11. repeated boot of the same installer artifact cannot wipe the target again;
12. installer result links do not dirty the repository;
13. repository persistence follows the resolved NixOS home directory;
14. `.#update` remains the steady-state dependency-update/activation path;
15. tests exercise lower-level mechanisms, the actual production profile with
    fixture facts, and the complete offline installer lifecycle.
