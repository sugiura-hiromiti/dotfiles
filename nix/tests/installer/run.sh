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
  "networkManagerEnabled": true,
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
    metadata-network-manager)
      sed -i 's/"networkManagerEnabled": true/"networkManagerEnabled": "true"/' "$destination"
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
  local state=$1
  local metadata=$2
  shift 2
  mkdir -p "$state"
  env \
    TEST_STATE="$state" \
    TEST_METADATA="$metadata" \
    TEST_DISKO="$TEST_DISKO" \
    TEST_WORK_SOURCE="$root/run/source" \
    TEST_WIFI=none \
    TEST_WIFI_SSID='Cafe: $[corner] "guest" \ room' \
    TEST_WIFI_PASSWORD='visible $[test] "password"\123!' \
    "$@" \
    expect <<'EOF'
set timeout 15
log_user 1
log_file -noappend $env(TEST_STATE)/transcript
set wifi_prompts 0
set awaiting_ssid 1
set max_wifi_prompts 1
if {$env(TEST_WIFI) eq "none"} {
  set max_wifi_prompts 0
} elseif {$env(TEST_WIFI) eq "retry" || $env(TEST_WIFI) eq "fail-skip"} {
  set max_wifi_prompts 2
}
spawn -noecho $env(INSTALLER)
expect {
  "Wi-Fi connection failed." {
    set awaiting_ssid 1
    exp_continue -continue_timer
  }
  "Wi-Fi SSID (leave empty to skip): " {
    # Nushell redraws visible input after each character. Only the first prompt
    # in a connection attempt should submit a value.
    if {!$awaiting_ssid} {
      exp_continue -continue_timer
    }
    set awaiting_ssid 0
    incr wifi_prompts
    if {$wifi_prompts > $max_wifi_prompts} {
      puts stderr "unexpected repeated Wi-Fi SSID prompt"
      exit 1
    }
    if {$env(TEST_WIFI) eq "skip" || ($env(TEST_WIFI) eq "fail-skip" && $wifi_prompts > 1)} {
      send -- "\r"
    } else {
      send -- "$env(TEST_WIFI_SSID)\r"
    }
    exp_continue -continue_timer
  }
  "Wi-Fi password: " {
    send -- "$env(TEST_WIFI_PASSWORD)\r"
    exp_continue -continue_timer
  }
  "Administrator password:" {
    send "secret\r"
    expect "Confirm administrator password:"
    send "secret\r"
    exp_continue -continue_timer
  }
  eof {}
  timeout { exit 124 }
}
catch wait result
exit [lindex $result 3]
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
  "$root/run/source/nix/profiles/hosts/test-host/deployments/qemu/facter.json"
test ! -e "$root/run/source/nix/profiles/hosts/test-host/facter.json"
test "$(cat "$state/store-snapshot/nix/profiles/hosts/test-host/deployments/qemu/facter.json")" = '{"fixture":true}'
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
grep -Fx -- "path:$post_source#nixosConfigurations.test-host--deployment-qemu--theme-dark--session-tty.config.dotfiles.installer.metadata" "$state/eval-args"
grep -Fx -- "path:$post_source#nixosConfigurations.test-host--deployment-qemu--theme-dark--session-tty.config.system.build.diskoScript" "$state/build-args"
grep -Fx -- "path:$post_source#test-host--deployment-qemu--theme-dark--session-tty" "$state/install-args"
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
test "$(cat "$root/mnt/persist/custom/alice-dotfiles/nix/profiles/hosts/test-host/deployments/qemu/facter.json")" = '{"fixture":true}'
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
test ! -e "$state/wifi-attempts"
test ! -e "$root/run/wifi.nmconnection"
test ! -e "$root/mnt/persist/etc/NetworkManager/system-connections/dotfiles-wifi.nmconnection"
if grep -F 'Wi-Fi SSID' "$state/transcript"; then
  printf '%s\n' 'installer prompted for Wi-Fi without an adapter' >&2
  exit 1
fi

# A selected Wi-Fi profile must reach persistent NetworkManager state before
# installation, without being copied into the source snapshot or secret argv.
for wifi_scenario in success retry; do
  wifi_state="$root/state-wifi-$wifi_scenario"
  run_installer "$wifi_state" "$metadata" "TEST_WIFI=$wifi_scenario"
  wifi_profile="$root/mnt/persist/etc/NetworkManager/system-connections/dotfiles-wifi.nmconnection"
  cmp "$wifi_state/network profiles/selected.nmconnection" "$root/run/wifi.nmconnection"
  cmp "$root/run/wifi.nmconnection" "$wifi_profile"
  test "$(stat -c %a "$root/run/wifi.nmconnection")" = 600
  test "$(stat -c %a "$wifi_profile")" = 600
  test "$(stat -c %a "$(dirname "$wifi_profile")")" = 700
  test "$(find "$(dirname "$wifi_profile")" -type f | wc -l)" -eq 1
  grep -Fx 'autoconnect=true' "$wifi_profile"
  if grep -F 'interface-name=' "$wifi_profile"; then
    printf '%s\n' 'Wi-Fi profile is still bound to the installer interface' >&2
    exit 1
  fi
  test "$(cat "$wifi_state/wifi-ssid")" = 'Cafe: $[corner] "guest" \ room'
  test "$(cat "$wifi_state/wifi-password")" = 'visible $[test] "password"\123!'
  grep -F 'visible $[test] "password"\123!' "$wifi_state/transcript"
  if grep -RF 'visible $[test] "password"\123!' "$wifi_state/store-snapshot" "$root/run/source" "$root/mnt/persist/custom/alice-dotfiles" "$wifi_state/nmcli-args"; then
    printf '%s\n' 'Wi-Fi password escaped into source files or command arguments' >&2
    exit 1
  fi
  grep -Fx -- "$wifi_profile" "$wifi_state/chown-calls"
  if [ "$wifi_scenario" = retry ]; then
    test "$(cat "$wifi_state/wifi-attempts")" -eq 2
    test "$(wc -l < "$wifi_state/wifi-deleted")" -eq 1
    test "$(sort -u "$wifi_state/wifi-attempt-names" | wc -l)" -eq 2
  else
    test "$(cat "$wifi_state/wifi-attempts")" -eq 1
  fi
done

# Both skipping immediately and declining after a failed connection leave no
# profile to transfer, including any state left by an earlier installer run.
for wifi_scenario in skip fail-skip; do
  wifi_state="$root/state-wifi-$wifi_scenario"
  run_installer "$wifi_state" "$metadata" "TEST_WIFI=$wifi_scenario"
  test ! -e "$root/run/wifi.nmconnection"
  test ! -e "$root/mnt/persist/etc/NetworkManager/system-connections/dotfiles-wifi.nmconnection"
  if [ "$wifi_scenario" = fail-skip ]; then
    test "$(cat "$wifi_state/wifi-attempts")" -eq 1
    test "$(wc -l < "$wifi_state/wifi-deleted")" -eq 1
    test ! -e "$wifi_state/network profiles/selected.nmconnection"
  else
    test ! -e "$wifi_state/wifi-attempts"
  fi
done

# Wi-Fi cannot proceed to disk modification without a profile file or a target
# configured to load the transferred NetworkManager connection.
disabled_nm_metadata="$root/disabled-network-manager.json"
sed 's/"networkManagerEnabled": true/"networkManagerEnabled": false/' "$metadata" > "$disabled_nm_metadata"
for wifi_scenario in disabled-network-manager missing-profile; do
  rm -rf "$root/dev"
  mkdir -p "$root/dev"
  wifi_state="$root/state-wifi-$wifi_scenario"
  wifi_metadata="$metadata"
  wifi_mode=missing-profile
  if [ "$wifi_scenario" = disabled-network-manager ]; then
    wifi_metadata="$disabled_nm_metadata"
    wifi_mode=success
  fi
  if run_installer "$wifi_state" "$wifi_metadata" "TEST_WIFI=$wifi_mode"; then
    printf '%s unexpectedly succeeded\n' "$wifi_scenario" >&2
    exit 1
  fi
  assert_pre_destructive "$wifi_state"
done

# NetworkManager is only required on the target when Wi-Fi was selected.
run_installer "$root/state-no-wifi-disabled-network-manager" "$disabled_nm_metadata"

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
  metadata-network-manager \
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
  case "$scenario" in
    build|no-disk|two-disks|alias-create)
      test -e "$failure_state/build-args"
      ;;
  esac
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
test -e "$alias_state/build-args"
test ! -e "$alias_state/disko-ran"
