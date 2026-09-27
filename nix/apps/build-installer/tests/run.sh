set -eu

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
export HOME="$test_root/home"
export XDG_CONFIG_HOME="$test_root/config"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"

repository="$test_root/repository"
state="$test_root/state"
mkdir -p "$repository/bin" "$repository/tmp"

printf '%s\n' ignored.txt > "$repository/.gitignore"
printf '%s\n' baseline > "$repository/tracked.txt"
printf '%s\n' '#!/bin/sh' 'printf executable\n' > "$repository/bin/tool"
chmod 0755 "$repository/bin/tool"
ln -s tracked.txt "$repository/tracked-link"
printf '%s\n' '{ outputs = _: {}; }' > "$repository/flake.nix"

git -C "$repository" init -q
git -C "$repository" add .
git -C "$repository" \
  -c user.name=fixture \
  -c user.email=fixture@example.invalid \
  commit -qm 'fixture baseline'
jj git init --colocate "$repository" >/dev/null

printf '%s\n' 'modified working-copy bytes' > "$repository/tracked.txt"
printf '%s\n' 'ignored one' > "$repository/ignored.txt"
printf '%s\n' 'unversioned one' > "$repository/unversioned.txt"

run_build() {
  (
    cd "$repository"
    BUILD_INSTALLER_TEST_REPOSITORY="$repository" \
    BUILD_INSTALLER_TEST_STATE="$state" \
    DOTFILES_HOST=foreign-build-host \
    DOTFILES_DEPLOYMENT=foreign-build-deployment \
    TMPDIR="$repository/tmp" \
      "$BUILD_INSTALLER_APP" "$@"
  )
}

first_output=$(run_build --host test-host)
test "$first_output" = /nix/store/fake-installer-1
test "$(cat "$state/package-1")" = installer-selection-test-host
test "$(cat "$state/stage-1/tracked.txt")" = 'modified working-copy bytes'
test -L "$state/stage-1/tracked-link"
test "$(readlink "$state/stage-1/tracked-link")" = tracked.txt
test -x "$state/stage-1/bin/tool"
test ! -e "$state/stage-1/ignored.txt"
test ! -e "$state/stage-1/unversioned.txt"
test ! -e "$state/stage-1/.git"
test ! -e "$state/stage-1/.jj"
test ! -e "$repository/result"

first_identity=$("$REAL_NIX" hash path "$state/stage-1")
printf '%s\n' 'ignored two' > "$repository/ignored.txt"
printf '%s\n' 'unversioned two' > "$repository/unversioned.txt"
second_output=$(run_build --host test-host)
test "$second_output" = /nix/store/fake-installer-2
second_identity=$("$REAL_NIX" hash path "$state/stage-2")
test "$first_identity" = "$second_identity"

deployment_output=$(run_build --host test-host --deployment qemu)
test "$deployment_output" = /nix/store/fake-installer-3
test "$(cat "$state/package-3")" = installer-selection-test-host--deployment-qemu

target_output=$(run_build --target test-host--deployment-qemu--theme-dark--session-tty)
test "$target_output" = /nix/store/fake-installer-4
test "$(cat "$state/package-4")" = installer-test-host--deployment-qemu--theme-dark--session-tty
test "$(cat "$state/eval-count")" = 4

expect_selection_failure() {
  if run_build "$@" > "$test_root/selection.log" 2>&1; then
    printf 'invalid selection unexpectedly succeeded: %s\n' "$*" >&2
    exit 1
  fi
  test "$(cat "$state/count")" = 4
  test "$(cat "$state/eval-count")" = 4
}

expect_selection_failure --deployment qemu
expect_selection_failure --target test-host--deployment-qemu --host test-host
expect_selection_failure --target test-host--deployment-qemu --deployment qemu
expect_selection_failure
expect_selection_failure --host ''
expect_selection_failure --target ''
expect_selection_failure --host test-host --deployment ''

if run_build --target undeclared-target > "$test_root/unknown-target.log" 2>&1; then
  printf '%s\n' 'undeclared target unexpectedly succeeded' >&2
  exit 1
fi
grep -F 'does not provide attribute' "$test_root/unknown-target.log"
test "$(cat "$state/count")" = 4
test "$(cat "$state/eval-package-5")" = installer-undeclared-target
test ! -e "$(cat "$state/eval-stage-path-5")"

for target in selection-test-host selection-test-host--deployment-qemu; do
  if run_build --target "$target" > "$test_root/alias-target.log" 2>&1; then
    printf 'selection alias accepted as an exact target: %s\n' "$target" >&2
    exit 1
  fi
  grep -F 'not a declared NixOS target' "$test_root/alias-target.log"
  test "$(cat "$state/count")" = 4
  eval_count=$(cat "$state/eval-count")
  test ! -e "$(cat "$state/eval-stage-path-$eval_count")"
done
test "$(cat "$state/eval-count")" = 7

if run_build --host test-host--deployment-qemu > "$test_root/alias-host.log" 2>&1; then
  printf '%s\n' 'deployment alias accepted as an undeclared host' >&2
  exit 1
fi
grep -F 'not a declared installer selection' "$test_root/alias-host.log"
test "$(cat "$state/count")" = 4
test ! -e "$(cat "$state/eval-stage-path-8")"

# A real targetHost may begin with selection-; only canonical identity matters.
selection_host_output=$(run_build --target selection-host--deployment-qemu--theme-dark--session-tty)
test "$selection_host_output" = /nix/store/fake-installer-5
test "$(cat "$state/package-5")" = installer-selection-host--deployment-qemu--theme-dark--session-tty
test "$(cat "$state/eval-count")" = 9

unsafe_state="$test_root/unsafe-state"
if (
  cd "$repository"
  BUILD_INSTALLER_TEST_REPOSITORY="$repository" \
  BUILD_INSTALLER_TEST_STATE="$unsafe_state" \
    "$BUILD_INSTALLER_UNSAFE_TEMP_APP" --host test-host
) > "$test_root/unsafe.log" 2>&1
then
  printf '%s\n' 'checkout-contained stage unexpectedly succeeded' >&2
  exit 1
fi
grep -F 'refusing to stage inside the checkout' "$test_root/unsafe.log"
test ! -e "$unsafe_state/count"
test ! -e "$repository/in-checkout-stage"
