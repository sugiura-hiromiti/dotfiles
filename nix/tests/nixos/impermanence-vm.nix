{
  lib,
  disko,
  pkgs,
  ...
}:
let
  targetSystem = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      disko.nixosModules.disko
      ../../modules/nixos/features/impermanence/impermanence.nix
      {
        boot = {
          loader = {
            systemd-boot = {
              enable = true;
            };
            grub = {
              enable = false;
            };
          };
        };
        dotfiles = {
          features = {
            impermanence = {
              enable = true;
            };
            storage = {
              partitionLabel = "test-system";
              provisioning = {
                disk = "/dev/vdb";
              };
            };
          };
        };
      }
    ];
  };
  diskoScript = targetSystem.config.system.build.diskoScript;
  targetTopLevel = targetSystem.config.system.build.toplevel;
in
pkgs.testers.runNixOSTest {
  name = "dotfiles.impermanence-vm";
  nodes = {
    machine = {
      virtualisation = {
        additionalPaths = [ targetTopLevel ];
        emptyDiskImages = [ 4096 ];
      };
    };
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("test -b /dev/vdb")
    machine.succeed("${diskoScript}")

    machine.succeed("test -b /dev/disk/by-partlabel/test-system")

    machine.succeed("mountpoint -q /mnt")
    machine.succeed("mountpoint -q /mnt/nix")
    machine.succeed("mountpoint -q /mnt/persist")
    machine.succeed("mountpoint -q /mnt/boot")
    machine.succeed(
        "${pkgs.nixos-install-tools}/bin/nixos-install "
        "--root /mnt "
        "--system ${targetTopLevel} "
        "--no-channel-copy "
        "--no-root-password "
    )

    machine.succeed("test -L /mnt/nix/var/nix/profiles/system")
    machine.succeed("test -e /mnt/etc/NIXOS")
    machine.succeed("test -e /mnt/boot/loader/loader.conf")
    machine.succeed(
        "test -e /mnt/boot/EFI/BOOT/"
        "BOOT${lib.toUpper pkgs.stdenv.hostPlatform.efiArch}.EFI"
    )
    installer.succeed("umount -R /mnt")
    installer.succeed("sync")
    installer.shutdown()

    target.state_dir = installer.state_dir
    target.start()
    target.wait_for_unit("multi-user.target")
  '';
}
