set -eu
umask 0077

root=$TEST_ROOT
rm -rf "$root"
mkdir -p "$root"
cleanup() {
  chmod -R u+w "$root" 2>/dev/null || true
  rm -rf "$root"
}
trap cleanup EXIT

metadata_file() {
  destination=$1
  sudo_enabled=${2:-true}
  cat > "$destination" <<EOF
{
  "primaryUser": {
    "name": "alice",
    "home": "/home/alice",
    "uid": 1000,
    "group": "users",
    "gid": 100,
    "isNormalUser": true,
    "extraGroups": ["wheel"],
    "hashedPasswordFile": "/persist/etc/dotfiles/password-alice.hash"
  },
  "sudoEnabled": $sudo_enabled,
  "mutableUsers": false,
  "boot": {
    "systemdBoot": true,
    "canTouchEfiVariables": false,
    "efiArch": "X64"
  },
  "preservation": {
    "backingPath": "/persist/custom/alice-dotfiles",
    "runtimePath": "/home/alice/dotfiles"
  }
}
EOF
}

invalid_metadata_file() {
  scenario=$1
  destination=$2
  metadata_file "$destination"
  case "$scenario" in
    metadata-sudo)
      sed -i 's/"sudoEnabled": true/"sudoEnabled": false/' "$destination"
      ;;
    metadata-home)
      sed -i 's|"home": "/home/alice"|"home": "/home/alice/../root"|' "$destination"
      ;;
    metadata-uid)
      sed -i 's/"uid": 1000/"uid": "1000"/' "$destination"
      ;;
    metadata-gid)
      sed -i 's/"gid": 100/"gid": "100"/' "$destination"
      ;;
    metadata-group)
      sed -i 's/"group": "users"/"group": ""/' "$destination"
      ;;
    metadata-normal)
      sed -i 's/"isNormalUser": true/"isNormalUser": false/' "$destination"
      ;;
    metadata-wheel)
      sed -i 's/"extraGroups": \["wheel"\]/"extraGroups": []/' "$destination"
      ;;
    metadata-password)
      sed -i 's|password-alice.hash|password-someone-else.hash|' "$destination"
      ;;
    metadata-mutable)
      sed -i 's/"mutableUsers": false/"mutableUsers": true/' "$destination"
      ;;
    metadata-boot)
      sed -i 's/"systemdBoot": true/"systemdBoot": false/' "$destination"
      ;;
    metadata-preservation)
      sed -i 's|"backingPath": "/persist/custom/alice-dotfiles"|"backingPath": "/persist/../escape"|' "$destination"
      ;;
    *)
      printf 'unknown invalid metadata scenario: %s\n' "$scenario" >&2
      exit 64
      ;;
  esac
}

run_installer() {
  state=$1
  metadata=$2
  shift 2
  mkdir -p "$state"
  env \
    TEST_STATE="$state" \
    TEST_METADATA="$metadata" \
    TEST_DISKO="$TEST_DISKO" \
    TEST_WORK_SOURCE="$root/run/source" \
    "$@" \
    expect <<EOF
set timeout 15
log_user 1
spawn -noecho $INSTALLER
expect {
  "Administrator password:" {
    send "secret\\r"
    expect "Confirm administrator password:"
    send "secret\\r"
    expect eof
  }
  eof {}
  timeout { exit 124 }
}
catch wait result
exit [lindex \$result 3]
EOF
}

assert_pre_destructive() {
  state=$1
  test ! -e "$state/disko-ran"
  test ! -e "$root/dev/dotfiles-install-target"
}

metadata="$root/metadata.json"
metadata_file "$metadata"

# A real frozen, offline flake evaluation must reject an incomplete existing
# lock graph without changing it. The local input is valid, so allowing lock
# updates must evaluate the same flake successfully.
lock_fixture="$root/incomplete-lock-flake"
mkdir -p "$lock_fixture/local-input"
cat > "$lock_fixture/flake.nix" <<'EOF'
{
  inputs.unresolved.url = "path:./local-input";
  outputs = { self, unresolved }: { value = unresolved.value; };
}
EOF
cat > "$lock_fixture/local-input/flake.nix" <<'EOF'
{
  outputs = { self }: { value = "lock-update-allowed"; };
}
EOF
cat > "$lock_fixture/flake.lock" <<'EOF'
{
  "nodes": {
    "root": { "inputs": {} }
  },
  "root": "root",
  "version": 7
}
EOF
cp "$lock_fixture/flake.lock" "$root/expected-incomplete-flake.lock"
if XDG_CACHE_HOME="$root/nix-cache" \
  "$REAL_NIX" \
    --store "$root/nix-store" \
    --extra-experimental-features 'nix-command flakes' \
    eval \
    --offline \
    --raw \
    --no-update-lock-file \
    "path:$lock_fixture#value" \
    > "$root/frozen-lock.stdout" 2> "$root/frozen-lock.stderr"
then
  printf '%s\n' 'incomplete frozen lock graph unexpectedly evaluated' >&2
  exit 1
fi
cat "$root/frozen-lock.stderr"
grep -F 'requires lock file changes but they' "$root/frozen-lock.stderr"
cmp "$root/expected-incomplete-flake.lock" "$lock_fixture/flake.lock"
XDG_CACHE_HOME="$root/nix-cache" \
  "$REAL_NIX" \
    --store "$root/nix-store" \
    --extra-experimental-features 'nix-command flakes' \
    eval \
    --offline \
    --raw \
    "path:$lock_fixture#value" \
    > "$root/updated-lock.stdout"
test "$(cat "$root/updated-lock.stdout")" = lock-update-allowed
if cmp -s "$root/expected-incomplete-flake.lock" "$lock_fixture/flake.lock"; then
  printf '%s\n' 'successful evaluation did not update the incomplete lock graph' >&2
  exit 1
fi

# A complete run exercises the real Nushell transaction around only the
# destructive/system fakes. A stale runtime tree and stale symlink must be
# replaced, and mutation after snapshotting must not affect any later input.
state="$root/state-success"
mkdir -p "$root/run/source" "$root/dev" "$state"
printf '%s\n' stale > "$root/run/source/stale-marker"
ln -s /dev/old "$root/dev/dotfiles-install-target"
run_installer "$state" "$metadata" TEST_MUTATE_WORKSPACE=1

test ! -e "$root/run/source/stale-marker"
test "$(cat "$state/facter-path")" = \
  "$root/run/source/nix/profiles/hosts/test/facter.json"
test "$(cat "$state/store-add-count")" = 1
test -L "$root/run/post-facter-source"
test "$(cat "$state/store-snapshot/source-marker")" = immutable
test "$(cat "$root/run/source/source-marker")" = mutated
test -x "$state/store-snapshot/bin/probe"

post_source="$state/store-snapshot"
test "$(cat "$state/root-args")" = \
  "$(printf '%s\n%s\n%s\n%s' \
    --realise \
    "$post_source" \
    --add-root \
    "$root/run/post-facter-source")"
grep -Fx -- "path:$post_source#nixosConfigurations.test-target.config.dotfiles.installer.metadata" "$state/eval-args"
grep -Fx -- "path:$post_source#nixosConfigurations.test-target.config.system.build.diskoScript" "$state/build-args"
grep -Fx -- "path:$post_source#test-target" "$state/install-args"
grep -Fx -- --no-update-lock-file "$state/eval-args"
grep -Fx -- --no-update-lock-file "$state/build-args"
grep -Fx -- --no-update-lock-file "$state/install-args"

test "$(readlink "$root/dev/dotfiles-install-target")" = /dev/vda
password_file="$root/mnt/persist/etc/dotfiles/password-alice.hash"
for mount in "$root/mnt" "$root/mnt/nix" "$root/mnt/persist"; do
  test "$(stat -c %a "$mount")" = 755
done
test "$(cat "$password_file")" = '$y$fixture-password-hash'
test "$(stat -c %a "$root/mnt/persist/etc")" = 755
test "$(stat -c %a "$root/mnt/persist/etc/dotfiles")" = 700
test "$(stat -c %a "$password_file")" = 600
password_temporary=$(sed -n '1p' "$state/password-mv-args")
test "$(dirname "$password_temporary")" = "$(dirname "$password_file")"
test "$(sed -n '2p' "$state/password-mv-args")" = "$password_file"
test ! -e "$password_temporary"
test "$(cat "$root/mnt/persist/custom/alice-dotfiles/source-marker")" = immutable
test -x "$root/mnt/persist/custom/alice-dotfiles/bin/probe"
test "$(cat "$state/mountpoints")" = \
  "$(printf '%s\n%s\n%s\n%s' \
    "$root/mnt" \
    "$root/mnt/nix" \
    "$root/mnt/persist" \
    "$root/mnt/boot")"
grep -Fx -- 'root:root' "$state/chown-calls"
grep -Fx -- '--recursive' "$state/chown-calls"
grep -Fx -- '1000:100' "$state/chown-calls"
test -e "$state/sync-ran"
test "$(cat "$state/umount-args")" = "$(printf '%s\n%s' --recursive "$root/mnt")"
test -e "$state/poweroff-ran"

# A failed attempt may leave runtime state. The next invocation must recreate
# it from the immutable source.
retry_state="$root/state-retry"
mkdir -p "$root/run/source"
printf '%s\n' retry-stale > "$root/run/source/retry-stale"
run_installer "$retry_state" "$metadata"
test ! -e "$root/run/source/retry-stale"

# Source-copy, facter, rooting, locked-input, metadata, Disko realization,
# disk-cardinality, and alias-creation failures do not reach Disko.
for scenario in \
  copy \
  facter \
  root \
  lock \
  metadata-sudo \
  metadata-home \
  metadata-uid \
  metadata-gid \
  metadata-group \
  metadata-normal \
  metadata-wheel \
  metadata-password \
  metadata-mutable \
  metadata-boot \
  metadata-preservation \
  malformed \
  build \
  no-disk \
  two-disks \
  alias-create
do
  rm -rf "$root/run" "$root/dev"
  mkdir -p "$root/dev"
  failure_state="$root/state-$scenario"
  failure_metadata="$metadata"
  extra=''
  case "$scenario" in
    copy) extra='TEST_COPY_FAIL=1' ;;
    facter) extra='TEST_FACTER_FAIL=1' ;;
    root) extra='TEST_ROOT_FAIL=1' ;;
    lock) extra='TEST_LOCK_INVALID=1' ;;
    metadata-*)
      failure_metadata="$root/invalid-$scenario.json"
      invalid_metadata_file "$scenario" "$failure_metadata"
      ;;
    malformed)
      failure_metadata="$root/malformed-metadata.json"
      printf '%s\n' '{"primaryUser":' > "$failure_metadata"
      ;;
    build) extra='TEST_BUILD_FAIL=1' ;;
    no-disk) extra='TEST_DISKS=none' ;;
    two-disks) extra='TEST_DISKS=two' ;;
    alias-create) extra='TEST_ALIAS_FAIL=1' ;;
  esac
  if run_installer "$failure_state" "$failure_metadata" $extra; then
    printf '%s unexpectedly succeeded\n' "$scenario" >&2
    exit 1
  fi
  assert_pre_destructive "$failure_state"
done

# An unexpected object at the alias path is preserved and blocks Disko.
rm -rf "$root/run" "$root/dev"
mkdir -p "$root/dev"
printf '%s\n' keep > "$root/dev/dotfiles-install-target"
alias_state="$root/state-alias-object"
if run_installer "$alias_state" "$metadata"; then
  printf '%s\n' 'unexpected alias object was accepted' >&2
  exit 1
fi
test "$(cat "$root/dev/dotfiles-install-target")" = keep
test ! -e "$alias_state/disko-ran"
