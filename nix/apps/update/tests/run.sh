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
test ! -e "$failure_repo/.git/dotfiles-update.lock"
test ! -e "$activation_failure_repo/.git/dotfiles-update.lock"

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
