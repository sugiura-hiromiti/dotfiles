# Target and Operation Architecture Specification

**Status:** Approved architecture baseline; implementation work may proceed

**Reviewed code baseline:**
`sugiura-hiromiti/dotfiles@ea53e744b2bdf2f07fcee6f008acb4f657c1168d`

**Authority:** This document is the normative source for Target and Operation
behavior. Destructive-review reports are evidence used to revise this document;
they are not independently normative. Later code revisions must be rechecked
against this specification.

## 1. Purpose

This specification defines the minimum architecture needed to:

- declare multi-host Home Manager, NixOS, and nix-darwin configurations;
- construct and publish explicit Targets;
- select an ordered, non-empty activation list at runtime;
- update persistent dependency state without mixing source or Candidate state;
- validate a Candidate before publication; and
- activate selected Targets sequentially.

It deliberately avoids generic axis, binding, query, snapshot, and capability
frameworks until a current requirement needs them.

## 2. Source-of-truth order

For implementation work, resolve information in this order:

1. This specification defines required behavior and non-requirements.
2. The active ExecPlan defines the selected implementation mechanism and task
   boundaries.
3. `docs/superpowers/plans/target-operation-roadmap.md` defines sequencing.
4. Current code is evidence of the implementation state, not the architecture.

If an active plan contradicts this specification, the plan must be corrected
before implementation continues.

## 3. Architecture boundary

The architecture contains two related flows.

### 3.1 Configuration definition

```text
Declarations + Authoring Inputs
            -> Target Construction
            -> Target Catalog + Nix Configuration Definitions
            -> Flake Outputs
```

### 3.2 Update execution

```text
Target Catalog + runtime/user/environment inputs
            -> Selection
            -> ordered activation Targets
            -> Operation
               - L0 -> L1
               - Candidate Validation
               - publication of L1
            -> Activation
```

These flows must not be collapsed into one Cartesian runtime table or one
untyped update script responsibility.

## 4. Terms and responsibilities

### 4.1 Declarations

Declarations define persistent configuration subjects and semantic value
domains. Current concepts include:

- Host;
- Host-local Account;
- `theme` values;
- `session` values; and
- enabled Target kinds.

An Account name is not a global identity. `Host A / alice` and
`Host B / alice` may both exist.

`host`, `hostName`, `targetHost`, and aliases may address one Host in different
contexts. They are not separate machines.

### 4.2 Semantic domains

Declared values such as `theme = { dark, light }` and
`session = { gui, tty }` are inputs available to Target Construction.

```text
semantic-domain membership != Target Catalog membership
```

Declaring two axes does not require every Cartesian combination to be a Target.

### 4.3 Target Construction

Target Construction is the only authority that emits Targets. It consumes
Declarations and authoring inputs and produces:

- configuration identity;
- public Target name;
- Target kind;
- Host and optional Account association;
- effective profile contributions; and
- Nix configuration inputs.

### 4.4 Target

A Target is an existing configuration identity emitted by Target Construction.

```text
Target exists iff Target Construction emits it
```

Evaluation success is not part of Target identity. A Target may exist and be
broken under a particular source and dependency state.

```text
Configuration result = Target + Source + Dependency State
```

### 4.5 Target Catalog

The Target Catalog is the set of Targets emitted from one source `S`.

It is not the Cartesian product of all semantic values and is not the set of
Targets that happened to evaluate successfully.

### 4.6 Selection

Selection observes runtime, user, and environment inputs and returns either:

- an ordered, non-empty list of existing activation Targets; or
- an explicit failure.

Home activation is optional. A valid selection may contain only a NixOS or
nix-darwin system Target.

If multiple Host candidates are equally valid, Selection must return an
explicit ambiguity unless an explicit policy resolves it. Account-to-Host data
is a hint, not a global identity relation.

### 4.7 Operation

One dependency-mutating Operation binds:

- one immutable source `S`;
- base dependency state `L0`;
- Candidate dependency state `L1`;
- ordered activation Targets; and
- the configured Candidate Validation policy.

The policy may remain an implementation/configuration choice. It is not
required to become a first-class domain entity.

Operation owns:

- repository serialization;
- the transition `L0 -> L1`;
- Candidate Validation against `S` and `L1`;
- authorization before publication; and
- publication of the accepted `L1`.

### 4.8 Activation

Activation applies the ordered activation Targets using the same `S` and `L1`
accepted by preflight.

Activation is:

- ordered;
- sequential; and
- non-atomic.

If a later Target fails, an earlier successful activation does not need to be
rolled back.

## 5. Candidate Validation

Candidate Validation is an Operation responsibility.

Conceptually:

```text
validateCandidate(S, L1, activationTargets, validationPolicy)
    -> accepted | rejected
```

Validation must include activation preflight for every activation Target.
Broader validation is policy-dependent.

Possible policies include:

| Policy       | Protected scope                          |
| ------------ | ---------------------------------------- |
| `local`      | selected activation Targets              |
| `host`       | Targets for the selected Host            |
| `system`     | Targets for the current Nix system       |
| `catalog`    | all published Targets                    |
| `repository` | a configured repository validation suite |

### 5.1 Current policy status

The repository has not selected a default Candidate Validation policy.

Current implementation behavior corresponds to `local`, but this observation
must not silently become the architecture default.

Until the policy is selected:

- local-only Candidate Validation may be preserved;
- implementation work must keep Candidate Validation separable from activation;
- no broader no-regression guarantee may be claimed; and
- no mandatory `validationTargets` object may be introduced.

`flake.lock` is repository-global state, but global mutation scope alone does
not imply a repository-wide no-regression policy. That guarantee requires an
explicit policy decision.

## 6. Normative invariants

### 6.1 Target membership

```text
Target exists iff Target Construction emits it
```

### 6.2 Target naming

Within one Target kind, distinct published Targets have distinct public names.

### 6.3 Selection

```text
Selection -> ordered non-empty existing Targets | explicit failure
```

### 6.4 Host ambiguity

```text
multiple equally valid Host candidates -> explicit ambiguity
```

unless a declared policy resolves the ambiguity.

### 6.5 Source consistency

For one Operation:

```text
Catalog      = Catalog(S)
Preflight    = Evaluation(S, L1, ...)
Activation   = Activation(S, L1, ...)
```

Repository edits made after `S` is captured must not alter that in-flight
Operation. An implementation may instead detect drift and stop before
publication and activation.

### 6.6 Dependency consistency

```text
L0 -> L1
Activation Preflight uses L1
Activation uses L1
```

### 6.7 Candidate publication

```text
publish(L1) -> CandidateValidation(S, L1) == accepted
```

A failed preflight must not publish `L1` and must not start activation.

### 6.8 Scope separation

Activation scope and Candidate Validation scope are independent concepts. They
may coincide under a local policy but need not coincide under another policy.

### 6.9 Serialization

```text
at most one dependency-mutating Operation per Git repository
```

The lock is shared by linked worktrees through the Git common directory.
Concurrent invocation may wait or fail explicitly. It must not interleave two
Candidates.

## 7. Current implementation status at the reviewed baseline

### 7.1 Confirmed non-conformance: Source consistency

`nix/apps/update/default.nix` builds `PLAN` from the evaluated flake source,
while `nix/apps/update/update.nu` evaluates and activates the mutable current
working directory. The implementation does not bind planning, preflight, and
activation to one `S`.

### 7.2 Confirmed non-conformance: serialization and Candidate consistency

`nix/apps/update/update.nu` does not acquire a repository Operation lock. It
preflights a temporary Candidate lock, copies it to the repository, and then
activates by reevaluating the mutable repository path. Two Operations can
therefore produce:

```text
Operation A preflight = LA
Operation A activation = LB
```

### 7.3 Confirmed non-conformance: System-only Operation

`nix/apps/update/update.nu` fails when Home lookup returns no Target, even when
a valid system Target exists.

### 7.4 Latent non-conformance: Host ambiguity

`nix/apps/update/plan.nix` flattens primary Account names into an
Account-to-Host hint map. A same-system collision can be collapsed instead of
reported as an ambiguity. Current declarations do not trigger the collision.

### 7.5 Unresolved policy: Candidate Validation scope

The implementation preflights selected activation Targets only. Whether the
repository intends `local`, `catalog`, or `repository` protection is unresolved.
This is a policy question, not evidence that the Target model is structurally
incapable.

### 7.6 Extensibility risk: Cartesian runtime construction

`nix/lib/runtime.nix` currently constructs `themes x sessions`. No current
declaration requires conditional applicability, so this is not a current
implementation violation. Extend Target Construction only when a real
non-Cartesian requirement appears.

## 8. Required falsification scenarios

### 8.1 Candidate failure

Given an activation Target whose evaluation fails under `S, L1`:

- `L1` is not published;
- activation is not started; and
- the previous repository lock remains unchanged.

The test must inspect the external command exit status explicitly; piping a
failed external command into an output-discarding command is not sufficient.

### 8.2 Concurrent Operations

Force this schedule with a barrier:

```text
A owns the Operation lock and reaches preflight(LA)
B attempts to begin a dependency-mutating Operation
A is released and activates
```

B must wait or fail before generating/publishing `LB`. A's activation must
observe `LA`.

### 8.3 Source drift

After preflight and before activation, mutate a tracked repository source file.
The Operation must either:

- continue preflight and activation from the already captured immutable `S`; or
- detect drift and stop before publication and activation.

It must not activate from the mutated source accidentally.

### 8.4 System-only selection

A fixture Host with a system Target and no Home Target must produce a non-empty
ordered activation list and execute it.

### 8.5 Host ambiguity

Two same-system Hosts with the same primary Account name and no explicit Host
hint must produce an ambiguity error.

### 8.6 Policy-parametric publication

Given `A` succeeds under `L1`, `B` fails, activation Targets are `[A]`, and the
Catalog is `{A, B}`:

- `local` may publish;
- `catalog` must reject;
- `repository` follows its configured suite; and
- unresolved policy demonstrates ambiguity rather than structural failure.

## 9. Explicit non-requirements

The current architecture does not require:

- a generic axis, binding, capability, provider, concern, or query framework;
- `Runtime`, `RuntimeContext`, `Identity`, `Role`, or `Snapshot` domain entities;
- `TargetRef`, `Realization`, `MaterializationSet`, or `PreparedOperation`;
- `validationTargets` as a mandatory first-class object;
- automatic affected-set inference for dependency changes;
- transactional multi-Target rollback;
- repository-wide Candidate Validation before its policy is selected; or
- non-Cartesian runtime membership before a declaration requires it.

## 10. Implementation boundaries

The first implementation slice fixes Source consistency, Candidate consistency,
and repository serialization together. These concerns share one Operation
boundary and must not be reported complete after adding only a lock.

Later independent slices address System-only selection and Host ambiguity.
Candidate Validation policy implementation begins only after the repository
owner selects a policy. Cartesian runtime construction remains deferred.

## 11. Decisions recorded

- Target existence remains independent from evaluation success.
- Semantic domains remain independent from Target Catalog membership.
- Activation scope and Candidate Validation scope remain distinct.
- Candidate Validation policy remains unresolved.
- Global `flake.lock` mutation does not by itself create a repository-wide
  no-regression guarantee.
- Operation consistency is repaired without introducing a new mandatory domain
  entity.
