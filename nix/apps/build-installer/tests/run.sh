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
    TMPDIR="$repository/tmp" \
      "$BUILD_INSTALLER_APP" --host test-host
  )
}

first_output=$(run_build)
test "$first_output" = /nix/store/fake-installer-1
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
second_output=$(run_build)
test "$second_output" = /nix/store/fake-installer-2
second_identity=$("$REAL_NIX" hash path "$state/stage-2")
test "$first_identity" = "$second_identity"

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
