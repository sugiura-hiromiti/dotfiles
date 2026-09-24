{
  lib,
  pkgs,
}:
let
  testRoot = "/build/dotfiles-installer-runtime";
  fixtureSource = pkgs.runCommandLocal "installer-runtime-source" { } ''
    mkdir -p "$out/nix/profiles/hosts/test" "$out/bin"
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
        target = "test-target";
        primaryAccount = "alice";
        source = fixtureSource;
        facterRelativePath = "nix/profiles/hosts/test/facter.json";
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
