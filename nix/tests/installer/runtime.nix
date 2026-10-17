{
  lib,
  pkgs,
  testRoot ? "/build/dotfiles-installer-runtime",
}:
let
  fixtureSource = pkgs.runCommandLocal "installer-runtime-source" { } ''
    mkdir -p "$out/nix/profiles/hosts/test-host/deployments/qemu" "$out/bin"
    printf '%s\n' locked > "$out/flake.lock"
    printf '%s\n' immutable > "$out/source-marker"
    printf '#!/bin/sh\nprintf executable\\n' > "$out/bin/probe"
    chmod 0555 "$out/bin/probe"
  '';

  fakeNix = pkgs.writeShellScriptBin "nix" (builtins.readFile ./fake-nix.sh);
  fakeNixStore = pkgs.writeShellScriptBin "nix-store" ''
    set -eu
    state=''${TEST_STATE:?}
    printf '%s\n' "$@" > "$state/root-args"
    test "$1" = --realise
    test "$3" = --add-root
    if [ "''${TEST_ROOT_FAIL:-0}" = 1 ]; then
      exit 73
    fi
    ln -s "$2" "$4"
    printf '%s\n' "$2"
  '';
  fakeFacter = pkgs.writeShellScriptBin "nixos-facter" ''
    set -eu
    state=''${TEST_STATE:?}
    test "$1" = -o
    if [ "''${TEST_FACTER_FAIL:-0}" = 1 ]; then
      exit 74
    fi
    mkdir -p "$(dirname "$2")"
    printf '{"fixture":true}\n' > "$2"
    printf '%s\n' "$2" > "$state/facter-path"
  '';
  fakeMkpasswd = pkgs.writeShellScriptBin "mkpasswd" ''
    set -eu
    printf '%s\n' "$@" > "''${TEST_STATE:?}/mkpasswd-args"
    IFS= read -r password
    printf '%s\n' "$password" > "$TEST_STATE/password-input"
    printf '%s\n' '$y$fixture-password-hash'
  '';
  fakeNmcli = pkgs.writeShellScriptBin "nmcli" ''
    set -eu
    state=''${TEST_STATE:?}
    profile="$state/network profiles/selected.nmconnection"
    uuid=11111111-2222-4333-8444-555555555555
    printf '%s\n' "$@" >> "$state/nmcli-args"
    case "$*" in
      '--get-values TYPE device status')
        printf '%s\n' ethernet
        if [ "''${TEST_WIFI:-none}" != none ]; then
          printf '%s\n' wifi
        fi
        ;;
      'radio wifi on')
        : > "$state/wifi-radio-enabled"
        ;;
      '--ask --show-secrets --wait 120 device wifi connect '* )
        test -f "$state/wifi-radio-enabled"
        test "$#" -eq 10
        test "$9" = name
        test -n "''${10}"
        printf '%s\n' "$8" > "$state/wifi-ssid"
        printf '%s\n' "''${10}" > "$state/wifi-connection-name"
        printf '%s\n' "''${10}" >> "$state/wifi-attempt-names"
        count=0
        if test -f "$state/wifi-attempts"; then
          count=$(cat "$state/wifi-attempts")
        fi
        count=$((count + 1))
        printf '%s\n' "$count" > "$state/wifi-attempts"
        printf 'Wi-Fi password: '
        stty echo < /dev/tty
        IFS= read -r password < /dev/tty
        printf '%s\n' "$password" > "$state/wifi-password"
        mkdir -p "$(dirname "$profile")"
        cat > "$profile" <<EOF
    [connection]
    id=''${10}
    uuid=$uuid
    type=wifi
    interface-name=wlan9
    autoconnect=false
    [wifi]
    ssid=$8
    [wifi-security]
    key-mgmt=wpa-psk
    psk=$password
    EOF
        printf '%s\n' unrelated-profile-secret > "$state/network profiles/unrelated.nmconnection"
        if [ "''${TEST_WIFI:-none}" = fail-skip ] || {
          [ "''${TEST_WIFI:-none}" = retry ] && [ "$count" -eq 1 ];
        }; then
          printf '%s\n' 'Connection activation failed' >&2
          exit 10
        fi
        ;;
      'connection delete id '*)
        test "$4" = "$(cat "$state/wifi-connection-name")"
        printf '%s\n' "$4" >> "$state/wifi-deleted"
        rm -f "$profile"
        ;;
      '--get-values connection.uuid connection show id '*)
        test "$6" = "$(cat "$state/wifi-connection-name")"
        printf '%s\n' "$uuid"
        ;;
      'connection modify uuid '*)
        test "$#" -eq 8
        test "$4" = "$uuid"
        test "$5" = connection.interface-name
        test -z "$6"
        test "$7" = connection.autoconnect
        test "$8" = yes
        sed -i '/^interface-name=/d; s/^autoconnect=false$/autoconnect=true/' "$profile"
        ;;
      '--terse --escape no --fields UUID,FILENAME connection show')
        printf '%s\n' "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee:$state/network profiles/unrelated.nmconnection"
        if [ "''${TEST_WIFI:-none}" != missing-profile ]; then
          printf '%s\n' "$uuid:$profile"
        fi
        ;;
      *)
        printf 'unexpected nmcli arguments: %s\n' "$*" >&2
        exit 64
        ;;
    esac
  '';
  fakeLsblk = pkgs.writeShellScriptBin "lsblk" ''
    set -eu
    test "$*" = '--json --output PATH,TYPE,RM,HOTPLUG'
    case ''${TEST_DISKS:-one} in
      none) printf '%s\n' '{"blockdevices":[]}' ;;
      one) printf '%s\n' '{"blockdevices":[{"path":"/dev/vda","type":"disk","rm":false,"hotplug":false},{"path":"/dev/sr0","type":"rom","rm":true,"hotplug":true}]}' ;;
      two) printf '%s\n' '{"blockdevices":[{"path":"/dev/vda","type":"disk","rm":false,"hotplug":false},{"path":"/dev/vdb","type":"disk","rm":false,"hotplug":false}]}' ;;
      *) exit 64 ;;
    esac
  '';
  fakeDisko = pkgs.writeShellScript "installer-runtime-disko" ''
    set -eu
    state=''${TEST_STATE:?}
    : > "$state/disko-ran"
    rm -rf ${testRoot}/mnt
    mkdir -p \
      ${testRoot}/mnt/boot \
      ${testRoot}/mnt/nix \
      ${testRoot}/mnt/persist
  '';
  fakeMountpoint = pkgs.writeShellScriptBin "mountpoint" ''
    set -eu
    test "$1" = --quiet
    printf '%s\n' "$2" >> "''${TEST_STATE:?}/mountpoints"
    test -d "$2"
  '';
  fakeChown = pkgs.writeShellScriptBin "chown" ''
    set -eu
    printf '%s\n' "$@" >> "''${TEST_STATE:?}/chown-calls"
  '';
  fakeCp = pkgs.writeShellScriptBin "cp" ''
    set -eu
    if [ "''${TEST_COPY_FAIL:-0}" = 1 ]; then
      exit 75
    fi
    exec ${lib.getExe' pkgs.coreutils "cp"} "$@"
  '';
  fakeLn = pkgs.writeShellScriptBin "ln" ''
    set -eu
    if [ "''${TEST_ALIAS_FAIL:-0}" = 1 ]; then
      exit 76
    fi
    exec ${lib.getExe' pkgs.coreutils "ln"} "$@"
  '';
  fakeMv = pkgs.writeShellScriptBin "mv" ''
    set -eu
    test "$#" -eq 2
    test "$(dirname "$1")" = "$(dirname "$2")"
    test "$(stat -c %a "$1")" = 600
    test ! -e "$2"
    printf '%s\n' "$@" > "''${TEST_STATE:?}/password-mv-args"
    exec ${lib.getExe' pkgs.coreutils "mv"} "$@"
  '';
  fakeNixosInstall = pkgs.writeShellScriptBin "nixos-install" ''
    set -eu
    state=''${TEST_STATE:?}
    test "$(command -v nix)" = ${lib.getExe fakeNix}
    for mount in ${testRoot}/mnt ${testRoot}/mnt/nix ${testRoot}/mnt/persist; do
      test "$(stat -c %a "$mount")" = 755
    done
    if [ "''${TEST_WIFI:-none}" = success ] || [ "''${TEST_WIFI:-none}" = retry ]; then
      profile=${testRoot}/mnt/persist/etc/NetworkManager/system-connections/dotfiles-wifi.nmconnection
      test -f "$profile"
      test "$(stat -c %a "$profile")" = 600
    fi
    printf '%s\n' "$@" > "$state/install-args"
    frozen_lock_count=0
    for argument in "$@"; do
      if [ "$argument" = --no-update-lock-file ]; then
        frozen_lock_count=$((frozen_lock_count + 1))
      fi
    done
    test "$frozen_lock_count" -eq 1
    mkdir -p ${testRoot}/mnt/boot/EFI/BOOT
    : > ${testRoot}/mnt/boot/EFI/BOOT/BOOTX64.EFI
  '';
  fakeSync = pkgs.writeShellScriptBin "sync" ''
    : > "''${TEST_STATE:?}/sync-ran"
  '';
  fakeUmount = pkgs.writeShellScriptBin "umount" ''
    set -eu
    printf '%s\n' "$@" > "''${TEST_STATE:?}/umount-args"
  '';
  fakePoweroff = pkgs.writeShellScriptBin "poweroff" ''
    : > "''${TEST_STATE:?}/poweroff-ran"
  '';

  installer =
    (import ../../installer/script.nix {
      inherit lib pkgs;
      toolOverrides = {
        nix = lib.getExe fakeNix;
        nixStore = lib.getExe fakeNixStore;
        facter = lib.getExe fakeFacter;
        mkpasswd = lib.getExe fakeMkpasswd;
        nmcli = lib.getExe fakeNmcli;
        cp = lib.getExe fakeCp;
        ln = lib.getExe fakeLn;
        mv = lib.getExe fakeMv;
        lsblk = lib.getExe fakeLsblk;
        mountpoint = lib.getExe fakeMountpoint;
        chown = lib.getExe fakeChown;
        nixosInstall = lib.getExe fakeNixosInstall;
        sync = lib.getExe fakeSync;
        umount = lib.getExe fakeUmount;
        poweroff = lib.getExe fakePoweroff;
      };
      paths = {
        runtimeRoot = testRoot + "/run";
        targetAlias = testRoot + "/dev/dotfiles-install-target";
        mountRoot = testRoot + "/mnt";
      };
    })
      {
        host = "test-host";
        target = "test-host--deployment-qemu--theme-dark--session-tty";
        primaryAccount = "alice";
        source = fixtureSource;
        facterRelativePath = "nix/profiles/hosts/test-host/deployments/qemu/facter.json";
        efiArch = "X64";
      };
in
pkgs.runCommandLocal "installer-runtime-check"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.expect
      pkgs.nushell
    ];
    INSTALLER = installer;
    REAL_NIX = lib.getExe pkgs.nix;
    TEST_DISKO = fakeDisko;
    TEST_ROOT = testRoot;
  }
  ''
    bash ${./run.sh}
    touch "$out"
  ''
