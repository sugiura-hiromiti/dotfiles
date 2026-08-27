# Target and Operation Implementation Roadmap

**Specification:**
`docs/superpowers/specs/2026-08-27-target-operation-design.md`

**Code baseline used to order the work:**
`ea53e744b2bdf2f07fcee6f008acb4f657c1168d`

## Purpose

This roadmap orders independently testable implementation slices. It is not an
ExecPlan and must not be used as a substitute for exact file-level steps.

Only the current slice receives a detailed ExecPlan. Later plans are written
against the code produced by earlier slices so their file references and tests
do not become stale.

## Status

| Slice                                 | Status                              | Policy dependency        |
| ------------------------------------- | ----------------------------------- | ------------------------ |
| 1. Operation consistency              | Ready for execution planning        | None                     |
| 2. System-only selection              | Ready after Slice 1                 | None                     |
| 3. Host ambiguity                     | Ready after Slice 2                 | None                     |
| 4. Candidate Validation policy        | Blocked on repository policy choice | Required                 |
| 5. Non-Cartesian runtime construction | Deferred extensibility risk         | New requirement required |

## Slice 1: Operation consistency

Fix these as one bounded Operation change:

- pin the evaluated flake source as immutable `S`;
- derive `PLAN` and runtime evaluation from the same `S`;
- generate Candidate `L1` in a private writable Operation workspace;
- use that workspace for both preflight and activation;
- publish exactly that `L1`;
- serialize dependency-mutating Operations per Git repository, including linked
  worktrees; and
- propagate Candidate evaluation failures before publication.

Acceptance evidence:

- preflight and activation record the same source marker and Candidate lock;
- repository mutation between them does not change the in-flight activation;
- a failed preflight leaves `flake.lock` unchanged and does not activate;
- a barrier-controlled second Operation cannot generate or publish `LB`; and
- the Operation lock is released on success and failure.

Active ExecPlan:
`docs/superpowers/plans/2026-08-27-operation-consistency.md`

## Slice 2: System-only selection

Change Selection so Home lookup is optional while the final ordered activation
list remains non-empty.

Required behavior:

- Home + system selection preserves the current Home-before-system order;
- Home-only remains valid;
- system-only becomes valid;
- neither Target produces an explicit selection failure; and
- missing requested Target variants still produce specific errors.

Required fixture: a Host with a system Target and no Home Target.

This slice must not alter Candidate Validation scope.

## Slice 3: Host ambiguity

Replace the flat Account-to-Host value with ambiguity-preserving hint data.

Required behavior:

- an explicit `--host` remains authoritative after alias resolution;
- hostname and environment hints retain their declared precedence;
- an Account hint may yield zero, one, or multiple Host candidates;
- one candidate resolves normally; and
- multiple equally valid candidates fail with candidate names in the error.

Required fixture: two Hosts on one Nix system sharing a primary Account name.

This slice must not make Account a global identity.

## Slice 4: Candidate Validation policy

No implementation starts until one default is selected and recorded in the
specification.

The policy decision must answer:

1. Does dependency publication protect only activation Targets, all Targets for
   the selected Host/system, the full Catalog, or a repository suite?
2. Are protected checks evaluation-only or build checks?
3. How are checks for another Nix system executed from the current Host?
4. Is an unavailable protected platform a rejection, a deferred CI gate, or an
   allowed exception?

Whichever policy is selected, implement it inside Candidate Validation without
adding a mandatory domain entity unless a separate current requirement proves
that the existing Operation policy boundary is insufficient.

## Slice 5: Non-Cartesian runtime construction

Do not implement this slice from the current specification.

It becomes eligible only when a declaration needs a conditional relation such
as one `theme/session` pair being valid while another is not. At that point,
extend Target Construction with the smallest declaration-specific mechanism.
Do not preemptively introduce a generic axis or binding framework.

## Cross-slice gates

Before starting any later slice:

1. Rebase or otherwise compare against the latest repository state.
2. Confirm the previous slice's acceptance tests still pass.
3. Re-read the specification's non-requirements.
4. Write a new ExecPlan with exact paths and commands for that code state.
5. Keep unresolved policy choices unresolved instead of guessing.
