# Operation Consistency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make one dependency-mutating update Operation use one immutable flake
source and one Candidate lock from preflight through activation while preventing
concurrent Operations from interleaving.

**Architecture:** Pin the evaluated flake `self.outPath` into the generated
update app as immutable source `S`. Copy `S` into a private writable workspace,
generate `L1` there, preflight and activate from that same workspace, and publish
its exact `flake.lock`. Protect the mutation with a fail-fast lock directory in
the Git common directory; keep Candidate Validation local without
turning validation scope into a domain object.

**Tech Stack:** Nix flakes, Nix expressions, Nushell, POSIX shell test fixtures,
Git metadata, `nix flake check`

**Spec:**
`docs/superpowers/specs/2026-08-27-target-operation-design.md`

## Global Constraints

- Code baseline is
  `ea53e744b2bdf2f07fcee6f008acb4f657c1168d`. Documentation-only commits on
  top of that baseline are expected. If any implementation path named below
  already differs, stop and revise this plan against the new code.
- `PLAN`, preflight, and activation must use the same immutable source `S`.
- Activation preflight and activation must use the same Candidate `L1`.
- A failed preflight must not publish `L1` or begin activation.
- At most one dependency-mutating Operation may run per Git repository,
  including linked worktrees.
- Candidate Validation remains the current local behavior in this slice.
- Do not introduce `validationTargets`, a Snapshot entity, or an affected-set
  model.
- Do not implement System-only selection, Host ambiguity, or non-Cartesian
  runtime construction in this plan.
- Preserve Home-before-system activation order.
- Keep `update.nu` focused on Selection and a single Operation call.
- Do not add `jq` to production or test dependencies.
- `.github/workflows/*.yml` remains generated from `nix/ci/default.nix`.

---

## Baseline guard

- [ ] **Step 1: Verify implementation paths still match the reviewed baseline**

Run:

```sh
git diff --exit-code ea53e744b2bdf2f07fcee6f008acb4f657c1168d -- \
  flake.nix \
  nix/apps/update/default.nix \
  nix/apps/update/plan.nix \
  nix/apps/update/update.nu \
  nix/checks.nix
```

Expected: exit code `0`. Documentation files may differ from the baseline.

Run:

```sh
sed -n '300,340p' flake.nix
sed -n '1,120p' nix/apps/update/default.nix
sed -n '1,140p' nix/apps/update/update.nu
sed -n '1,100p' nix/checks.nix
```

Expected: `apps.update` does not pass `self.outPath`; `update.nu` evaluates
`pwd`, preflights with `--reference-lock-file`, copies the Candidate to the
repository, and switches from the repository path.

---

## File structure after this plan

| Path | Responsibility |
|---|---|
| `flake.nix` | Pass the evaluated `self.outPath` to the update app |
| `nix/apps/update/default.nix` | Build PLAN and delegate script generation |
| `nix/apps/update/script.nix` | Render one executable with pinned constants and Nu modules |
| `nix/apps/update/update.nu` | Resolve Selection and invoke one Operation |
| `nix/apps/update/operation.nu` | Own workspace, validation, publication, locking, and activation |
| `nix/apps/update/tests/default.nix` | Build fixture update apps and expose flake checks |
| `nix/apps/update/tests/fake-nix.sh` | Record source/lock observations and provide barriers/failures |
| `nix/apps/update/tests/run.sh` | Execute behavioral Operation scenarios |
| `nix/checks.nix` | Publish update checks under `checks.<system>` |
| `README.org` | Document frozen-source and concurrency behavior |

---

### Task 1: Pin the evaluated source in the generated update app

**Files:**

- Create: `nix/apps/update/script.nix`
- Create: `nix/apps/update/tests/default.nix`
- Modify: `flake.nix:321-329`
- Modify: `nix/apps/update/default.nix:1-40`
- Modify: `nix/checks.nix:1-47`

**Interfaces:**

- Consumes: `self.outPath`, generated `planFile`, `pkgs.nushell`
- Produces: `mkUpdateScript { source, planFile }` and
  `checks.<system>.update-source-pin`

- [ ] **Step 1: Add the failing source-pin check**

Create `nix/apps/update/tests/default.nix` with this initial content:

```nix
{
  lib,
  pkgs,
}:
let
  mkUpdateScript = import ../script.nix { inherit lib pkgs; };
  fixtureSource = pkgs.runCommandLocal "update-source-fixture" { } ''
    mkdir -p "$out"
    printf '%s\n' L0 > "$out/flake.lock"
    printf '%s\n' S0 > "$out/source-marker"
  '';
  fixturePlan = pkgs.writeText "update-plan-fixture.json" (builtins.toJSON {
    aliases.test = "test";
    defaultHosts.tester = "test";
    themeByHour = lib.genAttrs (
      map (hour: if hour < 10 then "0${toString hour}" else toString hour) (lib.range 0 23)
    ) (_: "dark");
    hosts.test = {
      autoSession = {
        gui = "tty";
        tty = "tty";
      };
      defaultSession = "tty";
      home.tester.dark.tty = {
        name = "home-test";
        eval = "homeConfigurations.home-test.activationPackage.drvPath";
        authorize = [ ];
        switch = [
          "nix"
          "run"
          "nixpkgs#home-manager"
          "--"
          "switch"
          "--flake"
        ];
      };
      system = null;
    };
  });
  fixtureApp = mkUpdateScript {
    source = fixtureSource;
    planFile = fixturePlan;
  };
in
{
  update-source-pin = pkgs.runCommandLocal "update-source-pin-check" { } ''
    grep -F 'const SOURCE = "${fixtureSource}"' ${fixtureApp}
    grep -F 'const PLAN = "${fixturePlan}"' ${fixtureApp}
    touch "$out"
  '';
}
```

At the end of `nix/checks.nix`, merge these checks after the existing build
checks:

```nix
// (import ./apps/update/tests { inherit lib pkgs; })
```

- [ ] **Step 2: Run the source-pin check and verify it fails**

Run:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#checks.${system}.update-source-pin" --no-write-lock-file
```

Expected: FAIL because `nix/apps/update/script.nix` does not exist yet.

- [ ] **Step 3: Extract script rendering and inject immutable `SOURCE`**

Create `nix/apps/update/script.nix`:

```nix
{
  lib,
  pkgs,
}:
{
  source,
  planFile,
}:
pkgs.writeTextFile {
  name = "dotfiles-update";
  executable = true;
  text = ''
    #!${lib.getExe pkgs.nushell} --no-config-file
    const PLAN = "${planFile}"
    const SOURCE = "${source}"
    ${builtins.readFile ./update.nu}
  '';
  checkPhase = ''
    UPDATE_SCRIPT="$target" \
    ${lib.getExe pkgs.nushell} --no-config-file --commands \
    'if not (nu-check --debug $env.UPDATE_SCRIPT) { exit 1 }'
  '';
}
```

Replace the inline `pkgs.writeTextFile` block in
`nix/apps/update/default.nix` with:

```nix
  mkUpdateScript = import ./script.nix { inherit lib pkgs; };
  updateScript = mkUpdateScript {
    inherit planFile source;
  };
```

Add `source` to the argument set of `nix/apps/update/default.nix`.

Pass it from `flake.nix`:

```nix
          apps.update = import ./nix/apps/update {
            inherit
              lib
              pkgs
              system
              hosts
              hostNames
              mkTargetConfigEntries
              ;
            source = self.outPath;
          };
```

- [ ] **Step 4: Run the narrow check**

Run:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#checks.${system}.update-source-pin" --no-write-lock-file
nix flake check --all-systems --no-build --no-write-lock-file
```

Expected: both commands PASS. The generated app contains PLAN and SOURCE paths
from the same flake evaluation. Runtime behavior is still unchanged in this
task.

- [ ] **Step 5: Commit the source-pin boundary**

Run in a Git checkout:

```sh
git add \
  flake.nix \
  nix/apps/update/default.nix \
  nix/apps/update/script.nix \
  nix/apps/update/tests/default.nix \
  nix/checks.nix
git commit -m "refactor(update): pin evaluated source"
```

If the checkout is managed by Jujutsu, describe the current change with the same
message and start a new change instead of creating a parallel Git commit.

---

### Task 2: Use one private source/Candidate workspace through activation

**Files:**

- Create: `nix/apps/update/operation.nu`
- Create: `nix/apps/update/tests/fake-nix.sh`
- Create: `nix/apps/update/tests/run.sh`
- Modify: `nix/apps/update/script.nix`
- Modify: `nix/apps/update/update.nu:56-79`
- Modify: `nix/apps/update/tests/default.nix`

**Interfaces:**

- Consumes: `run-operation repository source orderedTargets`
- Produces: local `validate-candidate`, exact Candidate publication, sequential
  activation from the private workspace, and
  `checks.<system>.update-operation-consistency`

- [ ] **Step 1: Add a fake Nix executable with observable barriers**

Create `nix/apps/update/tests/fake-nix.sh`:

```sh
set -eu

state=${TEST_STATE:?TEST_STATE is required}
mkdir -p "$state"

last=
for argument in "$@"; do
  last=$argument
done

if [ "$1" = flake ] && [ "$2" = update ]; then
  flake=
  output=
  previous=
  for argument in "$@"; do
    if [ "$previous" = --flake ]; then flake=$argument; fi
    if [ "$previous" = --output-lock-file ]; then output=$argument; fi
    previous=$argument
  done
  if [ -z "$output" ]; then output="$flake/flake.lock"; fi
  printf '%s\n' "${TEST_CANDIDATE:?TEST_CANDIDATE is required}" > "$output"
  printf '%s\n' "$TEST_CANDIDATE" >> "$state/generated"
  exit 0
fi

if [ "$1" = eval ]; then
  reference=
  previous=
  for argument in "$@"; do
    if [ "$previous" = --reference-lock-file ]; then reference=$argument; fi
    previous=$argument
  done
  flake=${last%%#*}
  if [ -n "$reference" ]; then lock=$reference; else lock="$flake/flake.lock"; fi
  printf '%s %s\n' "$(cat "$flake/source-marker")" "$(cat "$lock")" >> "$state/preflight"
  if [ "${TEST_FAIL_PREFLIGHT:-0}" = 1 ]; then
    printf '%s\n' 'forced preflight failure' >&2
    exit 23
  fi
  if [ "${TEST_BLOCK_PREFLIGHT:-0}" = 1 ]; then
    : > "$state/preflight-waiting"
    while [ ! -e "$state/release-preflight" ]; do sleep 0.05; done
  fi
  printf '%s\n' /nix/store/test.drv
  exit 0
fi

if [ "$1" = run ] && [ "$2" = nixpkgs#home-manager ]; then
  flake=${last%%#*}
  if [ "${TEST_MUTATE_REPOSITORY:-0}" = 1 ]; then
    printf '%s\n' S2 > "$TEST_REPOSITORY/source-marker"
    printf '%s\n' LB > "$TEST_REPOSITORY/flake.lock"
  fi
  printf '%s %s\n' "$(cat "$flake/source-marker")" "$(cat "$flake/flake.lock")" >> "$state/activation"
  if [ "${TEST_FAIL_ACTIVATION:-0}" = 1 ]; then
    printf '%s\n' 'forced activation failure' >&2
    exit 24
  fi
  exit 0
fi

printf 'unexpected fake nix invocation:' >&2
printf ' %s' "$@" >&2
printf '\n' >&2
exit 64
```

- [ ] **Step 2: Add the behavioral test runner**

Create `nix/apps/update/tests/run.sh`:

```sh
set -eu

new_repository() {
  repository=$1
  mkdir -p "$repository"
  git -C "$repository" init -q
  printf '%s\n' L0 > "$repository/flake.lock"
  printf '%s\n' S0 > "$repository/source-marker"
}

run_update() {
  repository=$1
  shift
  (
    cd "$repository"
    env "$@" "$UPDATE_APP" \
      --host test \
      --account tester \
      --theme dark \
      --session tty \
      --system-session tty
  )
}

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

publish_repo="$root/publish-repo"
publish_state="$root/publish-state"
new_repository "$publish_repo"
run_update "$publish_repo" \
  TEST_STATE="$publish_state" \
  TEST_REPOSITORY="$publish_repo" \
  TEST_CANDIDATE=LA
test "$(cat "$publish_repo/flake.lock")" = LA
test "$(cat "$publish_state/preflight")" = 'S0 LA'
test "$(cat "$publish_state/activation")" = 'S0 LA'

isolation_repo="$root/isolation-repo"
isolation_state="$root/isolation-state"
new_repository "$isolation_repo"
run_update "$isolation_repo" \
  TEST_STATE="$isolation_state" \
  TEST_REPOSITORY="$isolation_repo" \
  TEST_CANDIDATE=LA \
  TEST_MUTATE_REPOSITORY=1
test "$(cat "$isolation_state/preflight")" = 'S0 LA'
test "$(cat "$isolation_state/activation")" = 'S0 LA'
test "$(cat "$isolation_repo/source-marker")" = S2
test "$(cat "$isolation_repo/flake.lock")" = LB

failure_repo="$root/failure-repo"
failure_state="$root/failure-state"
new_repository "$failure_repo"
if run_update "$failure_repo" \
  TEST_STATE="$failure_state" \
  TEST_REPOSITORY="$failure_repo" \
  TEST_CANDIDATE=LA \
  TEST_FAIL_PREFLIGHT=1
then
  printf '%s\n' 'preflight failure unexpectedly succeeded' >&2
  exit 1
fi
test "$(cat "$failure_repo/flake.lock")" = L0
test ! -e "$failure_state/activation"

activation_failure_repo="$root/activation-failure-repo"
activation_failure_state="$root/activation-failure-state"
new_repository "$activation_failure_repo"
if run_update "$activation_failure_repo" \
  TEST_STATE="$activation_failure_state" \
  TEST_REPOSITORY="$activation_failure_repo" \
  TEST_CANDIDATE=LA \
  TEST_FAIL_ACTIVATION=1
then
  printf '%s\n' 'activation failure unexpectedly succeeded' >&2
  exit 1
fi
test "$(cat "$activation_failure_repo/flake.lock")" = LA
test "$(cat "$activation_failure_state/activation")" = 'S0 LA'
```

Extend `nix/apps/update/tests/default.nix`:

```nix
  fakeNix = pkgs.writeShellScriptBin "nix" (builtins.readFile ./fake-nix.sh);
```

and add this check to the returned attribute set:

```nix
  update-operation-consistency = pkgs.runCommandLocal "update-operation-consistency-check"
    {
      nativeBuildInputs = [
        fakeNix
        pkgs.bash
        pkgs.coreutils
        pkgs.git
        pkgs.nushell
      ];
      UPDATE_APP = toString fixtureApp;
    }
    ''
      export PATH="${fakeNix}/bin:$PATH"
      bash ${./run.sh}
      touch "$out"
    '';
```

- [ ] **Step 3: Run the behavioral check and verify it fails**

Run:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#checks.${system}.update-operation-consistency" \
  --no-write-lock-file \
  --print-build-logs
```

Expected: FAIL. The current app preflights with a Candidate lock but switches
from the mutable repository path, so the isolation scenario records `S2 LB`
instead of `S0 LA`. On affected Nushell versions, the forced preflight failure
may also be swallowed by `| ignore` and publish unexpectedly.

- [ ] **Step 4: Add the private-workspace Operation**

Create `nix/apps/update/operation.nu`:

```nu
def fail-evaluation [target: record, result: record] {
	if not ($result.stderr | is-empty) { print -e $result.stderr }
	error make {
		msg: $"candidate evaluation failed for ($target.name): exit code ($result.exit_code)"
	}
}

def validate-candidate [flake: string, targets: list<record>] {
	# Current repository policy is local: activation Targets only.
	for target in $targets {
		let result = (
			^nix eval --raw $"($flake)#($target.eval)" | complete
		)
		if $result.exit_code != 0 { fail-evaluation $target $result }
	}
}

def authorize [targets: list<record>] {
	for target in $targets {
		if not ($target.authorize | is-empty) {
			run-external ...$target.authorize
		}
	}
}

def activate [flake: string, targets: list<record>] {
	for target in $targets {
		run-external ...$target.switch $"($flake)#($target.name)"
	}
}

def run-operation [repository: string, source: string, targets: list<record>] {
	let temporary = (mktemp -d)
	let flake = $temporary | path join "source"
	try {
		cp -r $source $flake
		^chmod -R u+w $flake
		^nix flake update --flake $flake
		validate-candidate $flake $targets
		authorize $targets
		cp ($flake | path join "flake.lock") ($repository | path join "flake.lock")
		activate $flake $targets
	} finally {
		if ($temporary | path exists) { rm -rf $temporary }
	}
}
```

This intentionally captures immutable-source semantics: edits to the repository
after the app is evaluated do not enter the in-flight Operation. The user reruns
the update to include those edits.

Embed the module before `update.nu` in `nix/apps/update/script.nix`:

```nix
    ${builtins.readFile ./operation.nu}
    ${builtins.readFile ./update.nu}
```

Replace `nix/apps/update/update.nu:56-79` with:

```nu
	let repository = pwd | path expand --strict
	let targets = [$home $system] | compact
	run-operation $repository $SOURCE $targets
```

Do not alter the preceding Selection logic in this task.

- [ ] **Step 5: Run the behavioral check and verify it passes**

Run:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#checks.${system}.update-operation-consistency" \
  --no-write-lock-file \
  --print-build-logs
nix build ".#checks.${system}.update-source-pin" --no-write-lock-file
```

Expected: PASS. Both preflight and activation record `S0 LA`; forced validation
failure leaves `L0` and no activation log.

- [ ] **Step 6: Commit the private-workspace Operation**

Run in a Git checkout:

```sh
git add \
  nix/apps/update/operation.nu \
  nix/apps/update/script.nix \
  nix/apps/update/update.nu \
  nix/apps/update/tests/default.nix \
  nix/apps/update/tests/fake-nix.sh \
  nix/apps/update/tests/run.sh
git commit -m "fix(update): keep source and candidate consistent"
```

If the checkout is managed by Jujutsu, describe the current change with the same
message and start a new change instead.

---

### Task 3: Serialize dependency mutation and publish the exact Candidate

**Files:**

- Modify: `nix/apps/update/script.nix`
- Modify: `nix/apps/update/operation.nu`
- Modify: `nix/apps/update/tests/run.sh`

**Interfaces:**

- Consumes: absolute Git common directory for the repository
- Produces: shared fail-fast `dotfiles-update.lock`, exact Candidate
  publication, and guaranteed cleanup on handled success/failure

- [ ] **Step 1: Add the barrier-controlled concurrency test**

Append this scenario to `nix/apps/update/tests/run.sh`:

```sh
concurrent_repo="$root/concurrent-repo"
state_a="$root/state-a"
state_b="$root/state-b"
new_repository "$concurrent_repo"

run_update "$concurrent_repo" \
  TEST_STATE="$state_a" \
  TEST_REPOSITORY="$concurrent_repo" \
  TEST_CANDIDATE=LA \
  TEST_BLOCK_PREFLIGHT=1 \
  >"$root/a.log" 2>&1 &
pid_a=$!

attempt=0
while [ ! -e "$state_a/preflight-waiting" ]; do
  attempt=$((attempt + 1))
  if [ "$attempt" -gt 200 ]; then
    printf '%s\n' 'operation A did not reach the preflight barrier' >&2
    kill "$pid_a" 2>/dev/null || true
    exit 1
  fi
  sleep 0.05
done

if run_update "$concurrent_repo" \
  TEST_STATE="$state_b" \
  TEST_REPOSITORY="$concurrent_repo" \
  TEST_CANDIDATE=LB \
  >"$root/b.log" 2>&1
then
  printf '%s\n' 'concurrent operation B unexpectedly succeeded' >&2
  touch "$state_a/release-preflight"
  wait "$pid_a"
  exit 1
fi

grep -F 'dependency update is already running' "$root/b.log"
test ! -e "$state_b/generated"
touch "$state_a/release-preflight"
wait "$pid_a"
test "$(cat "$state_a/preflight")" = 'S0 LA'
test "$(cat "$state_a/activation")" = 'S0 LA'
test "$(cat "$concurrent_repo/flake.lock")" = LA
test ! -e "$concurrent_repo/.git/dotfiles-update.lock"
```

- [ ] **Step 2: Run the check and verify the concurrency scenario fails**

Run:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#checks.${system}.update-operation-consistency" \
  --no-write-lock-file \
  --print-build-logs
```

Expected: FAIL because both Operations can currently reach Candidate generation.

- [ ] **Step 3: Inject a hermetic Git executable**

Add this constant to `nix/apps/update/script.nix` beside PLAN and SOURCE:

```nix
    const GIT = "${lib.getExe pkgs.git}"
```

The runtime no longer depends on whichever `git` happens to be first in PATH.

- [ ] **Step 4: Add fail-fast locking and exact Candidate publication**

Add these functions above `run-operation` in
`nix/apps/update/operation.nu`:

```nu
def operation-lock-path [repository: string] {
	let result = (
		run-external $GIT -C $repository rev-parse --path-format=absolute --git-common-dir | complete
	)
	if $result.exit_code != 0 {
		if not ($result.stderr | is-empty) { print -e $result.stderr }
		error make { msg: "update must run from a Git working tree" }
	}
	$result.stdout
	| str trim
	| path expand --strict
	| path join "dotfiles-update.lock"
}

def acquire-operation-lock [repository: string] {
	let lock = operation-lock-path $repository
	try {
		mkdir $lock
	} catch {
		error make {
			msg: $"dependency update is already running; lock: ($lock)"
		}
	}
	$lock
}

def publish-candidate [flake: string, repository: string] {
	cp -f ($flake | path join "flake.lock") ($repository | path join "flake.lock")
}
```

Replace `run-operation` with the nested-cleanup form:

```nu
def run-operation [repository: string, source: string, targets: list<record>] {
	let lock = acquire-operation-lock $repository
	try {
		let temporary = (mktemp -d)
		let flake = $temporary | path join "source"
		try {
			cp -r $source $flake
			^chmod -R u+w $flake
			^nix flake update --flake $flake
			validate-candidate $flake $targets
			authorize $targets
			publish-candidate $flake $repository
			activate $flake $targets
		} finally {
			if ($temporary | path exists) { rm -rf $temporary }
		}
	} finally {
		if ($lock | path exists) { rm -rf $lock }
	}
}
```

Acquisition happens before Candidate generation. Publication copies the exact
Candidate used by preflight from the private workspace while the repository-wide
lock is held. Crash-atomic lock replacement is not a requirement of this slice.

- [ ] **Step 5: Add cleanup assertions for failed validation**

After the failure scenario in `nix/apps/update/tests/run.sh`, add:

```sh
test ! -e "$failure_repo/.git/dotfiles-update.lock"
test ! -e "$activation_failure_repo/.git/dotfiles-update.lock"
```

This proves the outer `finally` releases the lock when Candidate Validation
rejects `L1`.

- [ ] **Step 6: Run the Operation check**

Run:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#checks.${system}.update-operation-consistency" \
  --no-write-lock-file \
  --print-build-logs
```

Expected: PASS. Operation B fails before writing `state_b/generated`; Operation
A records `S0 LA` in both stages; lock directories are absent after success and
validation failure.

- [ ] **Step 7: Commit serialization**

Run in a Git checkout:

```sh
git add \
  nix/apps/update/script.nix \
  nix/apps/update/operation.nu \
  nix/apps/update/tests/run.sh
git commit -m "fix(update): serialize dependency publication"
```

If the checkout is managed by Jujutsu, describe the current change with the same
message and start a new change instead.

---

### Task 4: Document behavior and run repository verification

**Files:**

- Modify: `README.org` under `Bootstrap / First switch`
- Update while executing: this ExecPlan's progress and decision records

**Interfaces:**

- Consumes: completed source/Candidate workspace and lock behavior
- Produces: user-visible operational contract and final verification evidence

- [ ] **Step 1: Document the observable update contract**

After the paragraph describing `u` in `README.org`, add:

```org
Each update captures one immutable flake source before dependency mutation.
Candidate evaluation and Home/NixOS/nix-darwin activation use a private copy of
that same source and the same candidate lock. Edits made after the update starts
are therefore applied only by the next invocation.

Only one dependency update may run in a Git repository at a time, including
linked worktrees. A concurrent invocation fails before generating a candidate
and reports the lock path; rerun it after the active update finishes. If an
abrupt process termination leaves the reported lock directory behind, verify
that no update process is active before removing that directory.
```

- [ ] **Step 2: Format and run the narrow checks**

Run:

```sh
nix fmt
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#checks.${system}.update-source-pin" --no-write-lock-file
nix build ".#checks.${system}.update-operation-consistency" \
  --no-write-lock-file \
  --print-build-logs
```

Expected: PASS.

- [ ] **Step 3: Run evaluation, lint, and workflow verification**

Run:

```sh
nix flake check --all-systems --no-build --no-write-lock-file
nix fmt -- --ci
nix build .#checks.aarch64-linux.deadnix --no-write-lock-file
nix build .#checks.aarch64-linux.statix --no-write-lock-file
nix run .#render-workflows
git diff --exit-code -- .github/workflows
```

Expected: every command exits `0`; rendering workflows produces no diff. If the
current machine cannot build an `aarch64-linux` check, run the two lint builds on
the Linux host/runner recorded in `nix/ci/default.nix` and record that evidence
before completion.

- [ ] **Step 4: Review the final diff against the specification**

Run:

```sh
git diff --check
git diff --stat
git diff -- \
  flake.nix \
  nix/apps/update \
  nix/checks.nix \
  README.org
```

Confirm all of the following from the diff and test logs:

- SOURCE is `self.outPath`, not runtime `pwd`;
- PLAN and SOURCE are injected by one script builder;
- preflight does not use a different reference lock from activation;
- activation receives the private workspace flake path;
- failed evaluation cannot be swallowed by `| ignore`;
- the Operation lock is acquired before `nix flake update`;
- lock cleanup occurs on success and validation failure;
- Candidate Validation still covers activation Targets only; and
- Selection logic, including the current Home requirement, was not changed.

- [ ] **Step 5: Commit documentation and verification state**

Run in a Git checkout:

```sh
git add README.org docs/superpowers/plans/2026-08-27-operation-consistency.md
git commit -m "docs(update): describe consistent operations"
```

If the checkout is managed by Jujutsu, describe the current change with the same
message. Do not start the next roadmap slice in this plan.

---

## Progress

- [ ] Baseline guard completed
- [ ] Task 1: evaluated source pinned
- [ ] Task 2: private source/Candidate workspace implemented
- [ ] Task 3: dependency mutation serialized
- [ ] Task 4: documentation and full verification completed

## Decision record

- The in-flight Operation uses immutable-source semantics rather than aborting
  on later worktree edits. A later invocation captures those edits.
- The lock is fail-fast rather than waiting. This keeps failure visible and
  avoids an unbounded hidden wait behind authorization or activation.
- The lock lives in the repository's absolute Git common directory so it does
  not alter flake source contents and is shared by linked worktrees.
- Candidate publication copies the exact private-workspace lock while the
  repository lock is held. Crash-atomic publication is outside this slice.
- Candidate Validation remains local for this slice because its default policy
  is unresolved.

## Completion evidence

The executor keeps this section current with exact command results, commit/change
identifiers, and any environment limitation. Completion may be claimed only
after every checkbox above is complete and all required verification commands
have recorded successful results.
