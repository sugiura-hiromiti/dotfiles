# Deployment Identity Design

Date: 2026-09-28  
Status: Proposed for implementation  
Repository baseline: `51b1ab6f2258921e1a6cdb21a60923f0e4813682`

## 1. Purpose

The dotfiles repository must support multiple platforms and multiple concrete system deployments for the same logical host.

For example, the logical host `aarch64-linux-a` must be able to define independently deployable configurations such as:

- Parallels
- QEMU
- real hardware

The change must preserve the existing Nix module composition model where possible. It must not turn deployment support into a general architecture rewrite.

Success means:

1. one logical host can declare multiple deployments;
2. each system deployment has a distinct identity and system target;
3. NixOS hardware facts are associated with the selected deployment rather than only with the host;
4. installer bootstrap works before Facter data exists;
5. update selects the deployment that belongs to the selected host and never silently crosses host/deployment identities;
6. Home Manager targets remain deployment-independent by default;
7. Darwin can use deployment-specific system modules without inheriting NixOS-only Facter or installer requirements.

## 2. Non-goals

This change does not include:

- removing or redesigning roles;
- redesigning the profile/variant architecture;
- renaming `runtime`, `runtimeAxes`, theme, or session concepts;
- making theme/session dynamically switchable at runtime;
- making Home Manager deployment-dependent by default;
- changing account semantics;
- replacing the existing NixOS installer, Preservation, Disko, or boot contracts except where deployment selection must flow through them.

Those changes may be considered separately.

## 3. Terminology and identities

### 3.1 Host

A host is the logical configuration identity already represented by a host directory and host metadata.

A host owns shared configuration such as:

- `system`;
- accounts;
- host variants;
- runtime/configuration-axis declarations;
- target kinds;
- one or more deployments.

A host is no longer sufficient by itself to identify a concrete installed system when it has multiple deployments.

### 3.2 Deployment

A deployment is a concrete deployable environment belonging to exactly one host.

Examples:

```text
(aarch64-linux-a, parallels)
(aarch64-linux-a, qemu)
(aarch64-linux-a, real)
```

Deployment names are scoped by host. A deployment named `qemu` under host A is not the same identity as `qemu` under host B.

If two QEMU instances require different hardware facts or system configuration, they are separate deployments, for example `qemu-test` and `qemu-ci`.

The deployment identity is:

```text
deployment identity = (host, deployment)
```

### 3.3 System target

A system target is the complete evaluated system configuration.

Its identity is:

```text
system target identity =
  deployment identity
  + each enabled configuration axis
```

For the current axes, examples are:

```text
aarch64-linux-a--deployment-qemu
aarch64-linux-a--deployment-qemu--theme-dark
aarch64-linux-a--deployment-qemu--session-gui
aarch64-linux-a--deployment-qemu--theme-dark--session-gui
```

Only axes enabled by the host's existing `runtime.targetAxes` participate in the public target name.

### 3.4 Home target

Home targets remain deployment-independent by default.

Their identity remains based on:

```text
host + account + enabled configuration axes
```

Adding system deployments must not multiply otherwise-identical standalone Home targets.

### 3.5 Declared and ready NixOS targets

A declared NixOS target exists because the host, deployment, and configuration axes declare it.

A ready NixOS target is a declared target whose selected deployment has the Facter report required to evaluate the final NixOS configuration.

Readiness controls normal NixOS configuration publication. It does not determine whether the host is intended to receive system updates.

## 4. Host and deployment model

A system-capable host must declare at least one deployment.

A Home-only host may declare no deployments.

The host metadata should represent deployments explicitly. The exact file layout may follow the existing host-profile layout, but the semantic shape is:

```nix
{
  system = "aarch64-linux";

  targets = [
    "home"
    "nixos"
  ];

  deployments = {
    parallels = {
      modules = [
        ./deployments/parallels/nixos.nix
      ];
    };

    qemu = {
      modules = [
        ./deployments/qemu/nixos.nix
      ];
    };

    real = {
      modules = [
        ./deployments/real/nixos.nix
      ];
    };
  };

  # Optional. Required only for operations that intentionally permit
  # host-only system selection.
  defaultDeployment = "parallels";
}
```

For a Darwin host, the same `deployments.<name>.modules` field contains nix-darwin modules instead of NixOS modules because the host already declares a single system target kind.

The existing invariant that one host cannot target both NixOS and Darwin remains unchanged.

## 5. Facter ownership and readiness

### 5.1 Ownership

For NixOS, a Facter report belongs to a deployment identity, not merely to the host.

The canonical report path must therefore be derived from both host and deployment. A suitable repository layout is:

```text
nix/profiles/hosts/<host>/deployments/<deployment>/facter.json
```

For example:

```text
nix/profiles/hosts/aarch64-linux-a/deployments/parallels/facter.json
nix/profiles/hosts/aarch64-linux-a/deployments/qemu/facter.json
nix/profiles/hosts/aarch64-linux-a/deployments/real/facter.json
```

The host-level Facter path must not be used as a fallback once deployment-specific identity is introduced, because doing so would make hardware ownership ambiguous.

### 5.2 Readiness

Each declared NixOS deployment independently exposes:

```text
facterPath
facterRelativePath
facterReady
```

`facterReady` is true only when that deployment's canonical Facter report exists.

Readiness remains NixOS-specific. Darwin deployments do not require Facter unless a future Darwin-specific feature explicitly introduces such a requirement.

### 5.3 Bootstrap rule

Installer generation must not require `facterReady`.

The required relationship is:

```text
declared NixOS deployment/target
  ├─ installer generation: allowed before Facter exists
  └─ normal nixosConfiguration publication
       └─ requires selected deployment to be ready
```

The deployment identity and Facter destination must be known before the installer runs Facter.

## 6. Target enumeration and naming

### 6.1 System targets

System target enumeration expands:

```text
host
  × declared deployments
  × enabled configuration-axis values
```

The public system target name must include a deployment segment immediately after `targetHost`:

```text
<targetHost>--deployment-<deployment>[--theme-<theme>][--session-<session>]
```

The existing target-name helper remains the single source of public target-name construction and must be extended rather than duplicating naming logic elsewhere.

Target-name uniqueness assertions remain required.

### 6.2 Home targets

Home target enumeration does not expand across deployments.

The current naming form remains:

```text
<targetHost>--account-<account>[--theme-<theme>][--session-<session>]
```

## 7. Module composition

Deployment modules are system modules and are composed directly by the system builder.

They are not represented as variant names and are not required to pass through `resolve-profiles.nix`.

Conceptually:

```text
existing common/system/host/profile modules
+ selected deployment.modules
+ existing system integration modules
```

Both the NixOS builder and Darwin builder must compose the selected deployment's modules.

Home Manager receives no deployment modules by default.

If a future deployment genuinely needs Home-specific configuration, that must be introduced explicitly rather than by automatically reusing system deployment modules.

### 7.1 Nix module precedence

Module list position must not be treated as a generic "last wins" override mechanism.

Shared defaults that deployments are expected to customize must use the appropriate Nix option priority, for example `lib.mkDefault`.

Requirements that must remain true after all modules are merged must be expressed as assertions against the final configuration.

The existing installer contracts in `nixos-bootstrap.nix` remain final-configuration contracts.

## 8. Installed deployment identity

### 8.1 Purpose

The active system generation must expose its deployment identity to runtime tools.

This is a projection of the active generation's declaration, not independent mutable machine state.

### 8.2 Contents

The identity contains only:

```json
{
  "host": "aarch64-linux-a",
  "deployment": "parallels"
}
```

Theme, session, account, or other configuration axes are not part of the deployment identity and must not be stored in this file.

### 8.3 Runtime path

The runtime-visible path is:

```text
/etc/dotfiles/identity.json
```

On NixOS this should be generated as part of the system configuration, for example with `environment.etc`.

Darwin system configurations that participate in deployment-aware automatic update selection must expose equivalent content at the same logical runtime path using the system-generation mechanism available to nix-darwin.

The identity file must not be independently preserved under `/persist`. It must follow activation and rollback of the system generation.

## 9. Update resolution

The update command gains deployment-aware system selection while preserving the existing theme/session policy.

### 9.1 Host resolution

Host selection keeps the current candidate model, with installed identity added as a candidate.

The precedence is:

1. explicit `--host`;
2. installed identity host;
3. `DOTFILES_HOST`;
4. short runtime hostname;
5. full runtime hostname;
6. existing account-to-default-host hint.

An explicit host is authoritative. If it is invalid, update must fail rather than silently selecting a different host.

### 9.2 Decide whether a system update is required

System-update intent must be determined before checking target readiness.

The decision uses:

1. the selected host's declared system target kind; and
2. the current runtime environment kind.

The required flow is:

```text
resolve host
  ↓
compare host's declared system kind with runtime kind
  ↓
if no system update is applicable:
    resolve/update Home without requiring deployment
  ↓
if system update is applicable:
    resolve deployment
    ↓
    resolve selected system target
    ↓
    check readiness
```

The absence of a ready system target must never be interpreted as permission to fall back to a Home-only update.

### 9.3 Deployment resolution

Deployment is resolved only when a system update requires it.

Precedence:

1. explicit `--deployment`;
2. installed identity deployment, but only when the installed identity host equals the resolved host;
3. the selected host's optional `defaultDeployment`;
4. otherwise unresolved, which is an error for a required system update.

Every selected deployment must be declared by the resolved host.

An invalid explicit deployment is an error and must not fall back to installed identity or a default.

If installed identity is used for the resolved host but its deployment is no longer declared by that host, system update must fail with a stale/invalid identity error rather than silently selecting another deployment.

### 9.4 Readiness during update

After host, deployment, theme, and session identify the intended system target:

- NixOS must verify that the target is ready;
- if the target is not ready because Facter is absent, update must report that the selected deployment requires a Facter report and fail the system update;
- it must not fall back to Home-only behavior;
- Darwin has no Facter readiness gate.

### 9.5 Theme and session

Deployment detection does not change the current theme/session selection behavior.

Unless explicitly overridden:

- theme continues to be selected by the existing time-of-day policy;
- session continues to be selected from the existing display-environment/runtime policy.

The installed deployment identity is not a record of the currently installed theme or session.

## 10. Installer resolution and bootstrap

Installer target resolution is independent of the machine used to build the installer.

The build machine's `/etc/dotfiles/identity.json` must never be used as an implicit installer destination.

### 10.1 Selection

The installer interface may resolve a destination through:

1. an explicit full `--target`; or
2. explicit `--host` plus `--deployment`, resolving configuration axes to that deployment's defaults; or
3. host-only selection only when the host explicitly declares `defaultDeployment`.

No implicit deployment may be borrowed from the build machine.

### 10.2 Validation

An explicit installer `--target` must be validated against declared NixOS system targets, not ready NixOS system targets.

This permits a target whose Facter report does not yet exist.

Invalid explicit targets must fail immediately and must not fall back to another target.

### 10.3 Bootstrap flow

The installer preserves the current post-Facter bootstrap structure:

```text
resolve declared target and deployment
  ↓
determine deployment-specific Facter destination
  ↓
build/boot installer without requiring Facter readiness
  ↓
run Facter on the destination machine
  ↓
write report to selected deployment's canonical path in staged source
  ↓
add post-Facter source to the Nix store
  ↓
re-evaluate the same selected system target
  ↓
validate final installer contracts
  ↓
realize Disko
  ↓
install the final system
```

The target selected before Facter collection must remain the target evaluated after Facter collection.

## 11. NixOS installer contracts

Deployment support does not transfer ownership of all boot or storage configuration to deployment modules.

Common installer requirements may remain common.

The selected deployment contributes to the final NixOS module graph. The existing installer contract then validates the merged final configuration.

For example, if the installer requires systemd-boot, removable fallback EFI behavior, Preservation, or impermanent root, those remain assertions on the final configuration unless a separate change intentionally revises the contract.

## 12. Darwin behavior

Darwin participates in deployment identity and deployment-specific system module composition when a Darwin host declares multiple deployments.

Darwin system target names therefore include the deployment segment.

Darwin does not participate in:

- NixOS Facter readiness;
- NixOS installer ISO generation;
- Disko/bootstrap behavior.

Deployment support must not introduce a Facter requirement for Darwin.

## 13. Validation and errors

The model must reject at evaluation or selection time:

- a system-capable host with no deployments;
- a `defaultDeployment` not declared by its host;
- duplicate generated system target names;
- an explicit deployment not declared by the resolved host;
- an installed deployment identity reused with a different resolved host;
- a stale installed deployment that is no longer declared by the matching host when it is selected for a system update;
- an explicit installer target that is not declared;
- a required NixOS system update whose selected target is not ready.

Errors must identify both host and deployment when deployment resolution is involved.

## 14. Required tests

The implementation is complete only when tests cover the following behaviors.

| Case | Expected result |
| --- | --- |
| One host declares Parallels and QEMU | Two distinct system deployment identities exist |
| Same host/deployments with runtime target axes | Distinct system targets include deployment and enabled axes |
| Same host has two deployments | Standalone Home targets are not duplicated |
| `--host A --deployment qemu`, A/qemu exists | A/qemu is selected |
| Explicit deployment does not exist under selected host | Error; no fallback |
| Installed identity is A/qemu and no explicit system identity is supplied | A/qemu may be selected |
| Installed identity is A/qemu but `--host B` is supplied | A/qemu deployment is not reused for B |
| Matching installed identity names a deployment removed from the current flake | System update errors |
| Home-only update path | Deployment is not required |
| Runtime and host require a NixOS system update but selected deployment lacks Facter | Error; no Home-only fallback |
| One deployment has Facter and another does not | Only the ready deployment's normal NixOS targets are published |
| Deployment lacks Facter | Installer generation remains possible |
| Installer `--target` names a declared but unready NixOS target | Target is accepted |
| Installer `--target` names an undeclared target | Error |
| Installer is built while running under a different installed identity | Build-machine identity does not affect installer destination |
| Installer runs for a selected deployment | Facter is written to that deployment's canonical path |
| NixOS deployment module changes an overridable shared default | Nix option priority produces the intended final configuration |
| Final configuration violates an installer contract | Installer metadata evaluation fails |
| Darwin host declares multiple deployments | Darwin targets are distinct and selected deployment modules are composed |
| Darwin deployment lacks Facter | Darwin target is not suppressed |
| Switch to a generation with identity A/parallels | `/etc/dotfiles/identity.json` reports A/parallels |
| Activate a previous NixOS generation via rollback | `identity.json` changes with the activated generation |

## 15. Expected implementation surface

The exact patch may vary, but the change is expected to touch these responsibilities:

- host normalization in `nix/lib/hosts.nix`;
- target enumeration/readiness in `nix/lib/targets.nix`;
- target naming in `nix/lib/target-names.nix`;
- NixOS system composition in `nix/configurations/nixos.nix`;
- Darwin system composition in `nix/configurations/darwin.nix`;
- NixOS runtime identity publication;
- installer package/target selection in `nix/flake/installer.nix` and `nix/apps/build-installer`;
- Facter destination handling in `nix/installer`;
- update-plan indexing in `nix/apps/update/plan.nix`;
- update runtime resolution in `nix/apps/update/update.nu`;
- checks and fixtures that exercise target enumeration, bootstrap, update, and rollback behavior.

The existing profile resolver should not be generalized merely to support deployment modules.

## 16. Migration constraints

Existing behavior should be preserved by assigning each current system-capable host an initial deployment representing its current concrete machine/environment.

Existing host-level NixOS Facter reports must be moved to the corresponding initial deployment path.

Home target names remain unchanged.

System target names intentionally change because deployment becomes part of system target identity.

Any scripts, CI checks, installer tests, or documentation that refer to old system target names must be updated as part of the same implementation.

## 17. Design invariants

The implementation must preserve these invariants:

1. `(host, deployment)` is the deployment identity.
2. A system target is the deployment identity plus enabled configuration axes.
3. Installed identity records only host and deployment.
4. Home targets are deployment-independent unless a future explicit requirement changes that rule.
5. System-update intent is determined independently of readiness.
6. A required but unready NixOS system target is an error, not a Home-only fallback.
7. Installer selection is based on declared targets and does not require Facter readiness.
8. Installer destination selection never consumes the build machine's installed identity.
9. Facter is owned and checked per NixOS deployment.
10. Darwin deployment support does not imply Facter or installer support.
11. Deployment system modules are composed directly by the system builder rather than disguised as variants.
12. Common boot/storage requirements remain final-configuration contracts unless separately redesigned.
13. Invalid explicit selections fail rather than silently falling back.
14. Installed deployment identity is only valid together with its matching host.
15. Runtime-visible identity follows system generation activation and rollback.

## 18. Scope boundary

This design solves one problem:

> Add deployment as an explicit system identity dimension so that one logical host can safely represent multiple concrete deployment environments across supported system platforms.

It does not attempt to simplify every existing domain concept at the same time. Unused role plumbing, profile cleanup, runtime naming, and other architecture cleanup remain independent follow-up work.
