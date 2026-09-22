{
  lib,
  pkgs,
  nixpkgs,
  disko,
  preservation,
}:
let
  fixture = import ./fixture.nix {
    inherit
      lib
      pkgs
      nixpkgs
      disko
      preservation
      ;
  };
  inherit (fixture)
    system
    efiArch
    facterRelativePath
    seedTarget
    source
    ;
  # Pause only the final unmount to inspect the real backing files. All disk
  # operations before and after this observation use the production tools.
  observedUmount = pkgs.writeShellScriptBin "umount" ''
    if [[ " $* " == *" /mnt "* ]]; then
      touch /run/e2e-before-unmount
      while ! test -e /run/e2e-release-unmount; do sleep 0.1; done
    fi
    exec ${lib.getExe' pkgs.util-linux "umount"} "$@"
  '';
  observedUtilLinux = pkgs.symlinkJoin {
    name = "installer-e2e-util-linux";
    paths = [
      observedUmount
      pkgs.util-linux
    ];
  };
  installerArguments = {
    inherit source facterRelativePath efiArch;
    inherit (fixture) host target primaryAccount;
  };
  observedInstaller =
    (import ../../installer/script.nix {
      inherit lib;
      pkgs = pkgs // {
        util-linux = observedUtilLinux;
      };
    })
      installerArguments;
  isoSystem = import ../../installer/iso.nix {
    inherit
      nixpkgs
      system
      source
      facterRelativePath
      ;
    inherit (installerArguments) host target primaryAccount;
    extraModules = [
      (nixpkgs + "/nixos/modules/testing/test-instrumentation.nix")
      {
        users.users.root.initialHashedPassword = lib.mkForce null;
        systemd.services.dotfiles-installer.serviceConfig.ExecStart = lib.mkForce (
          toString observedInstaller
        );
        nix.settings = {
          substituters = lib.mkForce [ ];
          connect-timeout = 1;
        };
        # Derivation roots include their build closures, allowing configuration
        # files affected by the real facter report to be rebuilt offline.
        isoImage.storeContents = [
          seedTarget.config.system.build.toplevel
          seedTarget.config.system.build.toplevel.drvPath
          seedTarget.config.system.build.diskoScript
          seedTarget.config.system.build.diskoScript.drvPath
        ];
      }
    ];
  };
  iso = isoSystem.config.system.build.isoImage;
  qemuCommon = import (nixpkgs + "/nixos/lib/qemu-common.nix") {
    inherit lib;
    inherit (pkgs) stdenv;
  };
  qemu = qemuCommon.qemuBinaryWith {
    qemuPkg = pkgs.qemu_test;
    forceAccel = true;
  };
  commonFlags = lib.concatStringsSep " " [
    "-m 4096"
    "-device virtio-gpu-pci"
    "-device qemu-xhci,id=xhci"
    "-device usb-kbd,bus=xhci.0"
    "-netdev user,id=net0,restrict=on"
    "-device virtio-net-pci,netdev=net0"
    "-drive if=pflash,format=raw,unit=0,readonly=on,file=${pkgs.OVMF.firmware}"
    "-drive if=pflash,format=raw,unit=1,readonly=on,file=${pkgs.OVMF.variables}"
    "-drive if=none,id=target,format=qcow2,file=/tmp/dotfiles-e2e-target.qcow2"
    "-device virtio-blk-pci,drive=target,bootindex=2"
  ];
  isoFlags = lib.concatStringsSep " " [
    "-device virtio-scsi-pci,id=scsi"
    "-drive if=none,id=installer,media=cdrom,readonly=on,file=${iso}/iso/${iso.isoName}"
    "-device scsi-cd,drive=installer,bus=scsi.0,bootindex=1"
  ];
in
pkgs.testers.runNixOSTest {
  name = "dotfiles-installer-e2e";
  requiredFeatures.kvm = true;
  nodes = { };
  testScript = ''
    import subprocess

    subprocess.run(["${pkgs.qemu_test}/bin/qemu-img", "create", "-f", "qcow2",
                    "/tmp/dotfiles-e2e-target.qcow2", "24G"], check=True)
    installer = create_machine("${qemu} ${commonFlags} ${isoFlags}", name="installer")

    with subtest("boot the actual ISO and run the installer"):
        installer.start()
        installer.wait_for_unit("getty@tty2.service")
        installer.wait_until_tty_matches("1", "[Pp]assword")
        installer.send_chars("installer-test-password\n")
        installer.wait_until_tty_matches("1", "[Cc]onfirm|[Rr]epeat|[Aa]gain")
        installer.send_chars("installer-test-password\n")
        installer.wait_for_file("/run/e2e-before-unmount", timeout=1800)

    with subtest("verify physical backing state before unmount"):
        for mount in ["/mnt", "/mnt/nix", "/mnt/persist", "/mnt/boot"]:
            installer.succeed(f"mountpoint -q {mount}")
        installer.succeed("test -b /dev/disk/by-partlabel/dotfiles-system")
        installer.succeed("test $(stat -c '%u:%g:%a' /mnt/persist/etc/dotfiles) = 0:0:700")
        installer.succeed("test $(stat -c '%u:%g:%a' /mnt/persist/etc/dotfiles/password-operator.hash) = 0:0:600")
        installer.succeed("grep -q '^[$]y[$]' /mnt/persist/etc/dotfiles/password-operator.hash")
        installer.succeed("test -f /mnt/persist/srv/operator/dotfiles/${facterRelativePath}")
        installer.succeed("test -x /mnt/persist/srv/operator/dotfiles/executable-probe")
        installer.succeed("test -L /mnt/persist/srv/operator/dotfiles/symlink-probe")
        installer.succeed("test $(stat -c '%u:%g' /mnt/persist/srv/operator/dotfiles/flake.nix) = 1441:1442")
        installer.succeed("test -e /mnt/boot/EFI/BOOT/BOOT${efiArch}.EFI")
        installer.succeed("touch /run/e2e-release-unmount")
        installer.wait_for_shutdown()

    target = create_machine("${qemu} ${commonFlags}", name="installed")
    with subtest("boot without ISO and authenticate the administrator"):
        target.start(allow_reboot=True)
        target.wait_for_unit("multi-user.target")
        target.wait_until_tty_matches("1", "login:")
        target.send_chars("operator\n")
        target.wait_until_tty_matches("1", "Password:")
        target.send_chars("installer-test-password\n")
        target.wait_until_succeeds("pgrep -u operator -x bash")
        target.succeed("su - operator -c 'printf \"installer-test-password\\n\" | sudo -S -k id -u' | grep -qx 0")
        target.succeed("test $(stat -c '%u:%g:%a' /persist/etc/dotfiles/password-operator.hash) = 0:0:600")
        target.succeed("su - operator -c 'test -w ~/dotfiles/flake.nix && test -x ~/dotfiles/executable-probe && echo survived > ~/dotfiles/persistent-marker'")

    with subtest("root resets while nix and preserved state survive reboot"):
        target.succeed("echo disposable > /disposable-marker")
        target.succeed("echo survived > /nix/persistent-marker")
        target.succeed("echo survived > /persist/persistent-marker")
        target.reboot()
        target.wait_for_unit("multi-user.target")
        target.succeed("test ! -e /disposable-marker")
        target.succeed("grep -qx survived /nix/persistent-marker")
        target.succeed("grep -qx survived /persist/persistent-marker")
        target.succeed("su - operator -c 'grep -qx survived ~/dotfiles/persistent-marker && test -w ~/dotfiles/flake.nix'")
        target.succeed("test $(stat -c '%u:%g:%a' /persist/etc/dotfiles/password-operator.hash) = 0:0:600")
        target.shutdown()
  '';
}
