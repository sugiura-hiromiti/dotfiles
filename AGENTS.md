# Repository instructions

## Repository model

- This is a Nix flake for Home Manager, NixOS, and nix-darwin configurations.
- Host declarations live under `nix/profiles/hosts/`.
- Target construction lives in `nix/lib/targets.nix` and related files.
- Update selection and execution live under `nix/apps/update/`.
- Generated GitHub workflows under `.github/workflows/` are outputs. Change
  `nix/ci/default.nix` and run `nix run .#render-workflows` instead of editing
  generated YAML directly.

## Target and Operation work

Before changing Target construction, update selection, dependency publication,
or activation, read these files completely:

1. `docs/superpowers/specs/2026-08-27-target-operation-design.md`
2. `docs/superpowers/plans/target-operation-roadmap.md`
3. The active ExecPlan named by the task prompt

The specification is authoritative for behavior and invariants. The active
ExecPlan is authoritative for the implementation slice. If the code, spec, and
plan disagree, stop and report the conflict before editing code.

Do not infer a default Candidate Validation policy from the current local-only
preflight. The default policy is unresolved. Do not introduce
`validationTargets` or another mandatory domain object merely to preserve a
possible future policy.

For significant refactors, use an ExecPlan under `docs/superpowers/plans/` and
keep its progress and decision records current while executing it.

## Engineering constraints

- Preserve the separation between Target membership, runtime selection,
  Candidate Validation, dependency publication, and activation.
- Keep `nix/apps/update/update.nu` focused on selection and orchestration. Put
  reusable operation mechanics in focused neighboring files.
- Do not add `jq` to the production update path. Nushell and Nix already provide
  the required structured-data operations.
- Preserve unrelated user changes. Do not rewrite files outside the active plan.
- Treat `flake.lock` publication as a repository mutation requiring explicit
  serialization.
- Tests must exercise observable behavior. Static source matching alone is not
  sufficient for concurrency, Source consistency, or Candidate consistency.

## Verification

Run the narrow check named by the active ExecPlan first. Before completion run:

```sh
nix flake check --all-systems --no-build --no-write-lock-file
nix fmt -- --ci
nix build .#checks.aarch64-linux.deadnix --no-write-lock-file
nix build .#checks.aarch64-linux.statix --no-write-lock-file
nix run .#render-workflows
git diff --exit-code -- .github/workflows
```

Run platform build checks when the changed behavior reaches those platforms or
when the active ExecPlan requires them.
