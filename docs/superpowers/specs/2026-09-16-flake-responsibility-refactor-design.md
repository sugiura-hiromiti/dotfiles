# Flake responsibility refactor

Date: 2026-09-16

## Intent and scope

The primary goal is clear ownership and explicit dependencies in the flake.
Making hosts, profiles, and tooling easier to extend is a secondary benefit.
File length is not the success criterion.

The agreed approach is hybrid: ordinary Nix functions construct configurations,
and small flake-parts modules publish outputs. Preserve the existing host/profile
model, target names, public outputs, inputs, lock file, and behavior. The current
planning task produces a design and implementation plan; implementation is a
separate step.

## Current structure

The 416-line root flake combines input declarations, host/runtime/target wiring,
configuration builders, and per-system tooling. Existing implementations already
live in `nix/lib/`, `nix/apps/`, `nix/checks.nix`, `nix/ci/`, and the configuration
module trees. The refactor gives the remaining construction and output assembly
code explicit owners while reusing those implementations.

## File ownership

| File                            | Owns                                                                                                                                        |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `flake.nix`                     | Input declarations and the call to `flake-parts.lib.mkFlake`                                                                                |
| `nix/flake/default.nix`         | Composition: instantiate the existing host/runtime/target helpers, derive supported systems, construct builders, and connect output modules |
| `nix/configurations/common.nix` | Profile-module resolution adapter and common/system configuration arguments                                                                 |
| `nix/configurations/home.nix`   | Home Manager construction, its package import and overlays, and Home-specific arguments/module stack                                        |
| `nix/configurations/nixos.nix`  | NixOS construction, account-default module, and reusable module-stack function                                                              |
| `nix/configurations/darwin.nix` | Darwin construction, account-default module, and Darwin module stack                                                                        |
| `nix/flake/configurations.nix`  | Publish Home Manager, NixOS, and Darwin configurations using existing target enumeration                                                    |
| `nix/flake/checks.nix`          | Per-system target selection, recovery fixture selection, and wiring into existing checks                                                    |
| `nix/flake/apps.nix`            | Publish the existing update and fix applications                                                                                            |
| `nix/flake/dev-shells.nix`      | Maintenance package lists and the default/Neovim shells                                                                                     |
| `nix/flake/formatting.nix`      | Import the treefmt flake module and connect the existing treefmt configuration                                                              |
| `nix/flake/ci.nix`              | Construct CI configuration and publish the per-system workflow renderer                                                                     |

The new flake modules are adapters around existing implementations. For example,
`nix/flake/checks.nix` selects dependencies and publishes checks;
`nix/checks.nix` continues to define their implementation. A short architecture
section in `README.org` will explain this distinction and where common changes go.

## Dependency contracts

`nix/flake/default.nix` is the composition root. It constructs the host registry,
runtime expansion, target helpers, and builders once, using the current
`nixpkgs.lib`. It passes only the dependencies each imported component needs.
Host and target discovery remain independent of per-system package sets.

Shared helpers expose the current `profileModules`, `commonSpecialArgs`, and
`systemSpecialArgs` functions. Their argument contents and conditional fields
remain unchanged. Home-specific package imports and skill-source arguments
belong in the Home Manager builder.

Each builder returns an attribute set with a `build` function taking one resolved
target configuration. The NixOS builder also exposes `modulesFor`. Its `build`
function and recovery tests use that same function. The account-default helper
for each operating system stays private to that operating system's builder.

Output modules receive shared functions/data as explicit import arguments. They
use normal flake-parts module arguments such as per-system `pkgs`, `system`, and
`config` where needed. No new custom option hierarchy or broad `_module.args`
registry is needed. The composition root supplies the original flake `self` to
the checks and apps adapters.

The configuration output module receives existing target helpers and the three
builders. The checks adapter receives target helpers, `nixos.modulesFor`, and
`common.systemSpecialArgs`, along with the external inputs used by existing tests.
The CI adapter receives hosts and target enumeration and performs package-dependent
workflow evaluation inside `perSystem`.

Data flows from host metadata through target helpers and builders to public
configuration outputs. Checks reference those final public outputs and reuse the
NixOS builder's module stack for recovery tests. Builders do not depend on checks,
apps, CI, or the final flake outputs.

## Behavior-preservation requirements

1. Keep inputs, their `follows` relationships, and `flake.lock` unchanged.
2. Preserve every public configuration name and the host-derived supported
   systems. Keep the existing naming, enumeration, validation, and profile
   resolution logic as their single sources of truth.
3. Preserve the three configuration output families, all existing check names,
   `packages.render-workflows`, `apps.update`, `apps.fix`, both development shells,
   and the treefmt formatter.
4. Preserve module list order, profile order, account defaults, argument fields,
   and constructor package sources. Relocated relative paths must still address
   the original module entrypoints and profile directories.
5. Preserve Home Manager's NUR-overlay package import separately from the
   flake-parts package set used for per-system tooling.
6. Keep Home-specific skill paths and system-specific Nix/Nix-agent packages in
   their respective argument paths. Preserve optional `account`/`accountName`
   fields and lazy access to system-specific inputs.
7. Keep recovery selection's existing host/TTY predicate and assertion. Its
   Linux-only consumer must remain lazy when Darwin outputs are evaluated.
8. Preserve checks' references to final `self` configuration outputs and the
   update application's `source = self.outPath` behavior.
9. Keep formatter consumers connected through their per-system
   `config.treefmt.build` values. Import the treefmt flake module once.
10. Preserve generated workflow contents and the existing public commands.

Existing error checks remain with their current owners: host and target
validation in `nix/lib/`, profile errors in the resolver, and recovery selection
in the checks adapter. This refactor introduces no new host/profile validation
rules.

## Migration sequence

1. Record a baseline of public output names, supported systems, representative
   target evaluations, and existing validation results with the locked inputs.
2. Extract common configuration helpers and the three builders. Temporarily wire
   them from the root flake, then verify configuration behavior before changing
   output assembly.
3. Introduce the composition root and configuration output module. Transfer
   existing host/runtime/target construction without changing the domain helpers.
4. Extract formatting and its consumers, checks, apps, development shells, and
   CI into their output modules. Preserve explicit shared dependencies and
   per-system evaluation.
5. Finish the root entrypoint, document ownership in the README, and complete the
   validation below.

Each stage should leave the flake evaluable. Use Jujutsu for implementation
history in an environment that permits repository metadata writes.

## Validation and completion criteria

- Compare pre/post supported systems and names in every public output family.
  Include configuration names explicitly; `nix flake show` alone is insufficient
  for comparing all Home Manager outputs.
- Evaluate every target's build derivation path on the corresponding supported
  platform, and compare selected semantic configuration values covering accounts,
  theme/session, package selection, and Home-only arguments. Define the exact
  queries in the implementation plan.
- Run the existing formatter check, deadnix, statix, and update-app tests. Inspect
  the extracted stacks and argument construction directly for preservation.
- Render workflows and require unchanged `.github/workflows/` contents.
- Check both development shells and the formatter entrypoint. Inspect app
  evaluation without running update or activation.
- Run the existing full flake checks on aarch64 Linux and aarch64 Darwin using
  appropriate machines or CI. Report any unexecuted platform checks explicitly.
- Verify that inputs and `flake.lock` have no changes.

Derivation-path equality is not a universal success criterion: changing the
repository source can legitimately change derivations that embed `self.outPath`,
including the update application and source-based lint checks. Output names,
semantic configuration values, existing tests, and reviewed changes provide the
preservation evidence. Investigate unexpected derivation changes rather than
accepting every difference as a source-path effect.

The finished refactor succeeds when each changed concern has a clear owner,
dependencies can be read at component boundaries, existing behavior is preserved,
and adding a host continues to use the existing metadata/profile mechanism.
