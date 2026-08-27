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
the Git common directory; preserve the current local-only Candidate Validation
behavior without selecting a default policy or turning validation scope into a
domain object.

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
- Evaluating the supported update launcher must not write `flake.lock` before
  the Operation acquires that repository-wide lock.
- Candidate Validation preserves the current local-only behavior in this slice;
  the repository's default policy remains unresolved.
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

- [x] **Step 1: Verify implementation paths still match the reviewed baseline**

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

| Path                                                 | Responsibility                                                    |
| ---------------------------------------------------- | ----------------------------------------------------------------- |
| `flake.nix`                                          | Pass the evaluated `self.outPath` to the update app               |
| `nix/apps/update/default.nix`                        | Build PLAN and delegate script generation                         |
| `nix/apps/update/script.nix`                         | Render one executable with pinned constants and Nu modules        |
| `nix/apps/update/update.nu`                          | Resolve Selection and invoke one Operation                        |
| `nix/apps/update/operation.nu`                       | Own workspace, validation, publication, locking, and activation   |
| `nix/apps/update/tests/default.nix`                  | Build fixture update apps and expose flake checks                 |
| `nix/apps/update/tests/fake-nix.sh`                  | Record source/lock observations and provide barriers/failures     |
| `nix/apps/update/tests/run.sh`                       | Execute behavioral Operation scenarios                            |
| `nix/apps/update/tests/launcher.sh`                  | Exercise the supported launcher's pre-Operation mutation boundary |
| `nix/checks.nix`                                     | Publish update checks under `checks.<system>`                     |
| `nix/modules/home/programs/nushell/config/config.nu` | Launch updates without pre-Operation lock publication             |
| `README.org`                                         | Document frozen-source and concurrency behavior                   |

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

- [x] **Step 1: Add the failing source-pin check**

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

- [x] **Step 2: Run the source-pin check and verify it fails**

Run:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#checks.${system}.update-source-pin" --no-write-lock-file
```

Expected: FAIL because `nix/apps/update/script.nix` does not exist yet.

- [x] **Step 3: Extract script rendering and inject immutable `SOURCE`**

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

- [x] **Step 4: Run the narrow check**

Run:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#checks.${system}.update-source-pin" --no-write-lock-file
nix flake check --all-systems --no-build --no-write-lock-file
```

Expected: both commands PASS. The generated app contains PLAN and SOURCE paths
from the same flake evaluation. Runtime behavior is still unchanged in this
task.

- [x] **Step 5: Commit the source-pin boundary**

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

- [x] **Step 1: Add a fake Nix executable with observable barriers**

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
  target=${last#*#}
  if [ -n "$reference" ]; then lock=$reference; else lock="$flake/flake.lock"; fi
  printf '%s %s\n' "$(cat "$flake/source-marker")" "$(cat "$lock")" >> "$state/preflight"
  printf '%s\n' "$target" >> "$state/preflight-targets"
  if [ "${TEST_FAIL_PREFLIGHT:-0}" = 1 ] || \
     [ "${TEST_FAIL_PREFLIGHT_TARGET:-}" = "$target" ]
  then
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

- [x] **Step 2: Add the behavioral test runner**

Create `nix/apps/update/tests/run.sh`:

```sh
set -eu

new_repository() {
  repository=$1
  mkdir -p "$repository"
  git -C "$repository" init -q
  printf '%s\n' L0 > "$repository/flake.lock"
  printf '%s\n' S0 > "$repository/source-marker"
  git -C "$repository" add flake.lock source-marker
  git -C "$repository" \
    -c user.name=fixture \
    -c user.email=fixture@example.invalid \
    commit -qm 'fixture baseline'
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

run_operation() {
  repository=$1
  shift
  (
    cd "$repository"
    env "$@" "$OPERATION_APP"
  )
}

wait_for_file() {
  marker=$1
  pid=$2
  message=$3
  attempt=0
  while [ ! -e "$marker" ]; do
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid" || true
      printf '%s\n' "$message" >&2
      exit 1
    fi
    attempt=$((attempt + 1))
    if [ "$attempt" -gt 200 ]; then
      printf '%s\n' "$message" >&2
      kill "$pid" 2>/dev/null || true
      exit 1
    fi
    sleep 0.05
  done
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

drift_repo="$root/drift-repo"
drift_state="$root/drift-state"
new_repository "$drift_repo"
run_update "$drift_repo" \
  TEST_STATE="$drift_state" \
  TEST_REPOSITORY="$drift_repo" \
  TEST_CANDIDATE=LA \
  TEST_BLOCK_AFTER_PREFLIGHT=1 \
  >"$root/drift.log" 2>&1 &
drift_pid=$!

wait_for_file \
  "$drift_state/after-preflight-waiting" \
  "$drift_pid" \
  'operation did not reach the post-preflight barrier'
printf '%s\n' S2 > "$drift_repo/source-marker"
touch "$drift_state/release-after-preflight"
wait "$drift_pid"
test "$(cat "$drift_state/preflight")" = 'S0 LA'
test "$(cat "$drift_state/activation")" = 'S0 LA'
test "$(cat "$drift_repo/source-marker")" = S2
test "$(cat "$drift_repo/flake.lock")" = LA

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

multi_failure_repo="$root/multi-failure-repo"
multi_failure_state="$root/multi-failure-state"
new_repository "$multi_failure_repo"
if run_operation "$multi_failure_repo" \
  TEST_STATE="$multi_failure_state" \
  TEST_REPOSITORY="$multi_failure_repo" \
  TEST_CANDIDATE=LA \
  TEST_FAIL_PREFLIGHT_TARGET='homeConfigurations.home-test-second.activationPackage.drvPath'
then
  printf '%s\n' 'second-target preflight failure unexpectedly succeeded' >&2
  exit 1
fi
test "$(cat "$multi_failure_repo/flake.lock")" = L0
test ! -e "$multi_failure_state/activation"
test "$(cat "$multi_failure_state/preflight")" = \
  "$(printf '%s\n%s' 'S0 LA' 'S0 LA')"
test "$(cat "$multi_failure_state/preflight-targets")" = \
  "$(printf '%s\n%s' \
    'homeConfigurations.home-test.activationPackage.drvPath' \
    'homeConfigurations.home-test-second.activationPackage.drvPath')"

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
  fixturePostPreflightBarrier = pkgs.writeShellScript "update-test-post-preflight-barrier" ''
    set -eu
    if [ "''${TEST_BLOCK_AFTER_PREFLIGHT:-0}" = 1 ]; then
      : > "''${TEST_STATE:?TEST_STATE is required}/after-preflight-waiting"
      while [ ! -e "$TEST_STATE/release-after-preflight" ]; do
        ${lib.getExe' pkgs.coreutils "sleep"} 0.05
      done
    fi
  '';
  fakeNix = pkgs.writeShellScriptBin "nix" (builtins.readFile ./fake-nix.sh);

  fixtureOperationApp = pkgs.writeTextFile {
    name = "dotfiles-operation-test";
    executable = true;
    text = ''
      #!${lib.getExe pkgs.nushell} --no-config-file
      const SOURCE = "${fixtureSource}"
      const GIT = "${lib.getExe pkgs.git}"
      ${builtins.readFile ../operation.nu}
      let targets = [
        {
          name: "home-test"
          eval: "homeConfigurations.home-test.activationPackage.drvPath"
          authorize: []
          switch: ["nix" "run" "nixpkgs#home-manager" "--" "switch" "--flake"]
        }
        {
          name: "home-test-second"
          eval: "homeConfigurations.home-test-second.activationPackage.drvPath"
          authorize: []
          switch: ["nix" "run" "nixpkgs#home-manager" "--" "switch" "--flake"]
        }
      ]
      run-operation (pwd | path expand --strict) $SOURCE $targets
    '';
  };
```

Define `fixturePostPreflightBarrier` before `fixturePlan`, and change the
fixture Home Target's `authorize` field to:

```nix
authorize = [ (toString fixturePostPreflightBarrier) ];
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
    OPERATION_APP = toString fixtureOperationApp;
  }
  ''
    export PATH="${fakeNix}/bin:$PATH"
    bash ${./run.sh}
    touch "$out"
  '';
```

- [x] **Step 3: Run the behavioral check and verify it fails**

Run:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#checks.${system}.update-operation-consistency" \
  --no-write-lock-file \
  --print-build-logs
```

Expected: FAIL because `nix/apps/update/operation.nu` does not exist yet. After
that module is added, these scenarios also falsify mutable-source activation,
swallowed preflight failures, and failure to validate every activation Target.

- [x] **Step 4: Add the private-workspace Operation**

Create `nix/apps/update/operation.nu`:

```nu
def fail-evaluation [target: record, result: record] {
	if not ($result.stderr | is-empty) { print -e $result.stderr }
	error make {
		msg: $"candidate evaluation failed for ($target.name): exit code ($result.exit_code)"
	}
}

def validate-candidate [flake: string, targets: list<record>] {
	# This slice preserves local-only behavior; the default policy remains unresolved.
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

- [x] **Step 5: Run the behavioral check and verify it passes**

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

- [x] **Step 6: Commit the private-workspace Operation**

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
- Modify: `nix/apps/update/tests/default.nix`
- Modify: `nix/apps/update/tests/run.sh`

**Interfaces:**

- Consumes: absolute Git common directory for the repository
- Produces: shared fail-fast `dotfiles-update.lock`, exact Candidate
  publication, and guaranteed cleanup on handled success/failure

- [x] **Step 1: Add the barrier-controlled concurrency test**

Append this scenario to `nix/apps/update/tests/run.sh`:

```sh
concurrent_repo="$root/concurrent-repo"
state_a="$root/state-a"
state_b="$root/state-b"
new_repository "$concurrent_repo"

concurrent_worktree="$root/concurrent-worktree"
git -C "$concurrent_repo" worktree add -q -b update-operation-b \
  "$concurrent_worktree" HEAD
test -f "$concurrent_worktree/.git"

common_a=$(git -C "$concurrent_repo" \
  rev-parse --path-format=absolute --git-common-dir)
common_b=$(git -C "$concurrent_worktree" \
  rev-parse --path-format=absolute --git-common-dir)
test "$common_a" = "$common_b"

run_update "$concurrent_repo" \
  TEST_STATE="$state_a" \
  TEST_REPOSITORY="$concurrent_repo" \
  TEST_CANDIDATE=LA \
  TEST_BLOCK_PREFLIGHT=1 \
  >"$root/a.log" 2>&1 &
pid_a=$!

wait_for_file \
  "$state_a/preflight-waiting" \
  "$pid_a" \
  'operation A did not reach the preflight barrier'
test -d "$common_a/dotfiles-update.lock"

if run_update "$concurrent_worktree" \
  TEST_STATE="$state_b" \
  TEST_REPOSITORY="$concurrent_worktree" \
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
test ! -e "$common_a/dotfiles-update.lock"
```

`new_repository` commits the fixture baseline before this scenario so the linked
worktree has a valid `HEAD`. A linked worktree's `.git` is a file, so every lock
assertion resolves the shared absolute Git common directory instead of assuming
that `<worktree>/.git` is a directory.

- [x] **Step 2: Run the check and verify the concurrency scenario fails**

Run:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#checks.${system}.update-operation-consistency" \
  --no-write-lock-file \
  --print-build-logs
```

Expected: FAIL because both Operations can currently reach Candidate generation.

- [x] **Step 3: Inject hermetic external executables**

Add these constants to `nix/apps/update/script.nix` beside PLAN and SOURCE:

```nix
const GIT = "${lib.getExe pkgs.git}"
const MKDIR = "${lib.getExe' pkgs.coreutils "mkdir"}"
```

Add the same `MKDIR` constant beside `GIT` in the direct
`fixtureOperationApp` defined by `nix/apps/update/tests/default.nix`. The
runtime no longer depends on whichever `git` or `mkdir` happens to be first in
PATH.

- [x] **Step 4: Add fail-fast locking and exact Candidate publication**

Add these functions above `run-operation` in
`nix/apps/update/operation.nu`:

```nu
def operation-lock-path [repository: string] {
	let result = (
		run-external $GIT "-C" $repository rev-parse "--path-format=absolute" "--git-common-dir" | complete
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
	let result = (run-external $MKDIR $lock | complete)
	if $result.exit_code != 0 {
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

- [x] **Step 5: Add cleanup assertions for handled failures**

After the activation-failure scenario in `nix/apps/update/tests/run.sh`, when
both fixture variables have been defined, add:

```sh
test ! -e "$failure_repo/.git/dotfiles-update.lock"
test ! -e "$activation_failure_repo/.git/dotfiles-update.lock"
```

This proves the outer `finally` releases the lock when Candidate Validation
rejects `L1` and when activation fails after publication.

- [x] **Step 6: Run the Operation check**

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

- [x] **Step 7: Commit serialization**

Run in a Git checkout:

```sh
git add \
  nix/apps/update/script.nix \
  nix/apps/update/operation.nu \
  nix/apps/update/tests/default.nix \
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
- Format mechanically: `nix/apps/update/update.nu` and
  `nix/apps/update/tests/default.nix`
- Format mechanically, with no wording or behavioral change:
  `docs/superpowers/plans/target-operation-roadmap.md` and
  `docs/superpowers/specs/2026-08-27-target-operation-design.md`

**Interfaces:**

- Consumes: completed source/Candidate workspace and lock behavior
- Produces: user-visible operational contract and final verification evidence

- [x] **Step 1: Document the observable update contract**

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

- [x] **Step 2: Format and run the narrow checks**

Repository-wide formatting includes pre-existing drift in the two authoritative
Target/Operation documents listed above. The user explicitly approved only the
formatter-generated table-alignment hunks in those files; do not change their
wording, policy, roadmap status, or behavior.

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

- [x] **Step 3: Run evaluation, lint, and workflow verification**

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

- [x] **Step 4: Review the final diff against the specification**

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

- [x] **Step 5: Commit documentation and verification state**

Run in a Git checkout:

```sh
git add README.org docs/superpowers/plans/2026-08-27-operation-consistency.md
git commit -m "docs(update): describe consistent operations"
```

If the checkout is managed by Jujutsu, describe the current change with the same
message. Do not start the next roadmap slice in this plan.

---

### Task 5: Prevent launcher evaluation from publishing a lock

**Files:**

- Modify: `nix/modules/home/programs/nushell/config/config.nu`
- Modify: the direct update example near the top of `flake.nix`
- Modify: `nix/apps/update/tests/default.nix`
- Create: `nix/apps/update/tests/launcher.sh`
- Update while executing: this ExecPlan's progress, decisions, and evidence

**Interfaces:**

- Consumes: the supported Nushell `u` launcher and Nix's flake-run options
- Produces: a no-write launcher evaluation boundary before `run-operation`

- [x] **Step 1: Add an observable launcher-level regression**

In `nix/apps/update/tests/default.nix`, build test-only `nix` and `sudo`
executables. The fake `nix` must record its exact arguments, write a sentinel
`flake.lock` in its current directory when `--no-write-lock-file` is absent,
and then exit nonzero to model a later rejected invocation. The fake `sudo`
accepts only `sudo -v`. Join both executables into one `LAUNCHER_BIN` directory
so the runner can explicitly prepend it after the config's Darwin PATH setup.

Linux Nix build sandboxes hide `/etc/os-release`, so `sys host` omits its
presentation `name` field before `u` is defined. On Linux only, include
`pkgs.libredirect.hook`, provide a test `os-release`, and set `NIX_REDIRECTS`
for the check. A standalone derivation proved that this makes
`sys host | get name` return `NixOS`. Do not change the production platform
probe merely to accommodate the sandbox.

Publish a new `update-launcher-lock-safety` check that runs
`nix/apps/update/tests/launcher.sh` against the actual Nushell configuration.
The runner creates a stub `$HOME/dotfiles/flake.nix`, loads the actual config,
re-prepends `LAUNCHER_BIN`, invokes `u`, and expects the modeled later failure.
It first asserts that the fake Nix process was reached, then asserts both:

```sh
test -f "$launcher_state/args"
test ! -e "$launcher_home/dotfiles/flake.lock"
test "$(cat "$launcher_state/args")" = \
  "$(printf '%s\n' run --no-write-lock-file '.#update' --)"
```

This is behavioral coverage of the supported entry point, not static source
matching. Without the flag, the fake Nix process observably publishes the
sentinel before failing.

- [x] **Step 2: Run the launcher check and verify RED**

Run:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#checks.${system}.update-launcher-lock-safety" \
  --no-write-lock-file \
  --print-build-logs
```

Expected: FAIL because the current `u` launcher omits the no-write flag and the
fake Nix process creates the sentinel `flake.lock` before returning failure.
Failure before the fake Nix argument file exists is a harness failure, not RED.

- [x] **Step 3: Close the supported launcher boundary**

Change the command inside `u` to:

```nu
nix run --no-write-lock-file .#update -- ...$args
```

Update the direct invocation example at the top of `flake.nix` to use:

```sh
nix run --no-write-lock-file path:.#update -- --host <host> --account <account> --theme <theme> --session <session>
```

`--no-write-lock-file` still permits Nix to resolve the app with an in-memory
lock, but it leaves the repository lock unchanged. Candidate generation and
the only intended publication remain inside the serialized Operation.

- [x] **Step 4: Verify GREEN and existing Operation regressions**

Run:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#checks.${system}.update-launcher-lock-safety" \
  --no-write-lock-file \
  --print-build-logs
nix build ".#checks.${system}.update-source-pin" --no-write-lock-file
nix build ".#checks.${system}.update-operation-consistency" \
  --no-write-lock-file \
  --print-build-logs
```

Expected: every command exits `0`; the supported launcher leaves no sentinel,
and all Source/Candidate/serialization behavior remains intact.

- [x] **Step 5: Repeat mandatory repository verification**

Run:

```sh
nix flake check --all-systems --no-build --no-write-lock-file
nix fmt -- --ci
nix build .#checks.aarch64-linux.deadnix --no-write-lock-file
nix build .#checks.aarch64-linux.statix --no-write-lock-file
nix run .#render-workflows
git diff --exit-code -- .github/workflows
git diff --check
```

Expected: every command exits `0`, workflow rendering has no diff, Candidate
Validation remains unresolved, and no later roadmap slice changes.

- [x] **Step 6: Commit the final-review correction and evidence**

Run in a Git checkout:

```sh
git add \
  flake.nix \
  nix/modules/home/programs/nushell/config/config.nu \
  nix/apps/update/tests/default.nix \
  nix/apps/update/tests/launcher.sh
git commit -m "fix(update): prevent launcher lock publication"
git add docs/superpowers/plans/2026-08-27-operation-consistency.md
git commit -m "docs(plan): record launcher boundary verification"
```

If the checkout is managed by Jujutsu, describe the changes with the same
messages. Do not change the Candidate Validation policy or begin Slice 2.

---

## Progress

- [x] Baseline guard completed
- [x] Task 1: evaluated source pinned
- [x] Task 2: private source/Candidate workspace implemented
- [x] Task 3: dependency mutation serialized
- [x] Task 4: documentation and full verification completed
- [x] Task 5: launcher evaluation prevented from publishing a lock

## Decision record

- The approved preflight amendment adds behavioral coverage for a real linked
  worktree, tracked source drift at a post-preflight barrier, and rejection by
  a later activation Target. These strengthen Slice 1 acceptance evidence
  without changing Selection or choosing a Candidate Validation policy.
- The in-flight Operation uses immutable-source semantics rather than aborting
  on later worktree edits. A later invocation captures those edits.
- The lock is fail-fast rather than waiting. This keeps failure visible and
  avoids an unbounded hidden wait behind authorization or activation.
- The lock lives in the repository's absolute Git common directory so it does
  not alter flake source contents and is shared by linked worktrees.
- Candidate publication copies the exact private-workspace lock while the
  repository lock is held. Crash-atomic publication is outside this slice.
- Git option arguments passed through Nushell's `run-external` are quoted so
  Nushell 0.115 forwards them instead of parsing them as its own flags. This is
  a syntax-only correction; the Git invocation and lock-path behavior are
  unchanged.
- Lock acquisition uses a hermetic coreutils `mkdir` because Nushell 0.115's
  built-in `mkdir` succeeds when the directory already exists. The external
  command supplies the required atomic create-or-fail boundary.
- Final formatting may apply only formatter-generated table alignment to the
  Target/Operation specification and roadmap. The user approved that mechanical
  exception so the mandated repository-wide formatter check can pass; it does
  not expand this slice's behavior or roadmap scope.
- The supported `u` launcher and direct command example use
  `--no-write-lock-file` because app evaluation necessarily precedes
  `run-operation`. This prevents Nix from publishing a generated or updated
  repository lock outside serialization while still allowing in-memory app
  evaluation.
- The launcher regression keeps the production platform probe unchanged. On
  Linux, its Nix sandbox supplies `/etc/os-release` through `libredirect`; on
  every platform, the runner prepends one joined fake-command directory after
  loading the actual config so Darwin PATH setup cannot bypass the test doubles.
- This slice preserves the current local-only Candidate Validation behavior and
  does not select the repository's unresolved default policy.

## Completion evidence

The executor keeps this section current with exact command results, commit/change
identifiers, and any environment limitation. Completion may be claimed only
after every checkbox above is complete and all required verification commands
have recorded successful results.

- 2026-08-28 baseline guard: PASS against
  `ea53e744b2bdf2f07fcee6f008acb4f657c1168d` for every implementation path
  named by the plan.
- 2026-08-28 baseline all-systems evaluation: PASS with `--no-eval-cache` after
  evaluating the pinned Catppuccin package derivations into a writable
  task-local Nix cache. Initial attempts exposed a read-only default cache and
  lazily unregistered Catppuccin derivation paths; no repository change was
  needed.
- Environment limitation: `.git/objects` is mounted read-only in this sandbox,
  so Jujutsu cannot snapshot the working copy and per-task change descriptions
  cannot be created here. Read-only Git inspection remains available.
- Task 1 review-only commit: `15519f1 refactor(update): pin evaluated source`.
  The narrow `update-source-pin` build and the all-systems no-build flake check
  both passed from that exact commit through a local Git flake URL. Task review
  found no Critical, Important, or Minor issues.
- Task 2 review-only commits: `8a8199c test(update): cover operation
  consistency` and `1626ed6 fix(update): keep source and candidate consistent`.
  The Operation and source-pin checks passed from the exact GREEN commit, as did
  all-systems evaluation, deadnix, statix, and workflow verification. Task review
  found no Critical, Important, or Minor issues.
- Task 3 RED commit: `8d7b0c1 test(update): cover dependency serialization`.
  Its commit-pinned Operation check failed at the first missing-lock assertion,
  before either production lock implementation existed.
- Task 3 GREEN head: `024ab94 fix(update): create operation lock atomically`,
  following the plan-recorded Nushell argument and atomic-`mkdir` corrections.
  Commit-pinned `update-operation-consistency` and `update-source-pin` builds
  both passed, and scoped format CI reported zero changes. The controller reran
  both narrow checks from `024ab94` and received exit `0`.
- Task 3 independent review found the implementation behavior compliant with no
  Critical issues. Its Important finding was this missing plan bookkeeping;
  the implementation itself required no correction. Its Minor diagnostic note
  (all external `mkdir` failures use the prescribed contention message) does
  not weaken the tested create-or-fail boundary and is left unchanged in this
  slice.
- 2026-08-28 Task 4 formatting: `nix fmt` exited `0` and reported three changed
  files. The Target/Operation specification and roadmap changes normalize to
  byte-identical content after Markdown table spacing and separator widths are
  canonicalized, proving that their hunks are alignment-only. The remaining
  formatter output affects only examples and a table in this ExecPlan;
  `nix/apps/update/update.nu` and `nix/apps/update/tests/default.nix` were
  already formatted and did not change.
- 2026-08-28 Task 4 narrow checks: on `aarch64-linux`, both
  `nix build .#checks.aarch64-linux.update-source-pin
  --no-write-lock-file` and `nix build
  .#checks.aarch64-linux.update-operation-consistency --no-write-lock-file
  --print-build-logs` exited `0`.
- 2026-08-28 Task 4 repository verification: `nix flake check --all-systems
  --no-build --no-write-lock-file` reported `all checks passed!`; `nix fmt --
  --ci` reported `0 changed`; the required `aarch64-linux` deadnix and statix
  builds exited `0`; `nix run .#render-workflows` exited `0`; and `git diff
  --exit-code -- .github/workflows` exited `0`.
- 2026-08-28 Task 4 diff review: `git diff --check` exited `0`; the scoped diff
  and mechanical assertions confirmed all nine required invariants, including
  unchanged Selection behavior and unresolved Candidate Validation policy.
- Task 4 documentation and formatter commit: `4843147 docs(update): describe
  consistent operations` in the review-only Git store.
- 2026-08-28 post-completion bookkeeping format check: `nix fmt -- --ci`
  exited `0` with `204 files` processed and `0 changed`.
- 2026-08-28 independent Task 4 review: APPROVED with no Critical, Important,
  or Minor findings. The reviewer independently confirmed the README contract,
  four-path scope, formatter-only authoritative-document changes, unresolved
  Candidate Validation policy, and unchanged later roadmap slices.
- 2026-08-28 controller verification on the final tree: both update checks,
  all-systems no-build flake check, format CI, deadnix, statix, workflow render
  and zero workflow diff, and `git diff --check` all exited `0`. The
  all-systems check ended with `all checks passed!`; format CI reported `204
  files` and `0 changed`.
- 2026-08-28 whole-slice final review: WITH FIXES. The supported `u` launcher
  could let Nix write a generated or updated repository `flake.lock` while
  evaluating `.#update`, before the Operation acquired its Git-common-directory
  lock. An isolated real-Nix probe reproduced the boundary: without
  `--no-write-lock-file`, Nix created `flake.lock` before a later app-resolution
  failure; with the flag, the same failure left the lock absent. The user
  approved adding Task 5 to close and behaviorally test this Slice 1 boundary.
- Task 5 initial RED commit: `02f27a9 test(update): cover launcher lock
  publication`. Its first commit-pinned run failed before fake Nix because the
  Linux Nix sandbox hid `/etc/os-release`, so `sys host` omitted `name`; this was
  rejected as a harness failure rather than accepted as RED.
- Task 5 portable-harness commit: `441b0bb test(update): make launcher harness
  portable`, after `fe6ad85 docs(plan): make launcher harness portable`
  recorded the approved correction. Its commit-pinned launcher check exited
  `1` only after the fake Nix argument marker existed and the missing flag had
  created the sentinel, reporting `launcher published sentinel flake.lock
  before failing`.
- Task 5 GREEN commit: `1ac4694 fix(update): prevent launcher lock publication`.
  Commit-pinned `update-launcher-lock-safety`, `update-source-pin`, and
  `update-operation-consistency` checks all exited `0` from exact commit
  `1ac4694370e9d1015256ce1b57ebca5dec381a53`.
- 2026-08-28 Task 5 repository verification: the direct all-systems working-tree
  command exposed the known review-store limitation because real Git does not
  track `launcher.sh`. The exact GREEN commit retry through `direnv exec .`
  exited `0` and ended with `all checks passed!`; `nix fmt -- --ci` processed
  `204 files` with `0 changed`; commit-pinned `aarch64-linux` deadnix and statix
  builds exited `0`; workflow rendering exited `0` with no generated diff; and
  `git diff --check` exited `0`.
- `result` was absent before Task 5 builds. The mandatory lint builds created a
  symlink to the statix check, and only that symlink was removed after
  verification.
- 2026-08-28 independent Task 5 review: APPROVED with no Critical, Important,
  or Minor findings. The reviewer confirmed that the observable launcher test
  reaches fake Nix, detects the pre-fix publication, verifies exact post-fix
  arguments, and leaves Candidate policy and later slices unchanged.
- 2026-08-28 controller verification at exact review commit
  `e036d1eb1fc538dde155f347103b5c043a013879`: the launcher, source-pin, and
  Operation-consistency checks exited `0`; the all-systems no-build flake check
  ended with `all checks passed!`; format CI processed `204 files` with `0
  changed`; commit-pinned deadnix and statix builds exited `0`; workflow
  rendering exited `0` with no generated diff; and `git diff --check` exited
  `0`.
- Controller environment limitation: the exact working-tree all-systems command
  and its `direnv exec` retry cannot include untracked `launcher.sh` because the
  real Git index is read-only in this sandbox. Both failed only while resolving
  that absent Git-flake path. The review-only commit tracks the same working-tree
  bytes, and the required all-systems check passed from that exact commit.
- 2026-08-28 final-head verification at review-only commit `ce60061`: the
  all-systems no-build check ended with `all checks passed!`; format CI processed
  `204 files` with `0 changed`; deadnix and statix builds exited `0`; workflow
  rendering produced no generated diff; `git diff --check` exited `0`; and no
  `result` symlink remained.
- 2026-08-28 fresh whole-slice re-review at `ce60061`: `Ready to merge? Yes`
  with zero Critical and Important findings. The reviewer confirmed that Task 5
  resolves the earlier launcher publication boundary, Candidate Validation
  remains unresolved, and no later roadmap slice started. The previously
  recorded Minor contention diagnostic remains accepted and unchanged.
