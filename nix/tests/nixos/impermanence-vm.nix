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
    installer = {
      virtualisation = {
        additionalPaths = [ targetTopLevel ];
        emptyDiskImages = [ 4096 ];
      };
    };
  };
  testScript = ''
    installer.start()
    installer.wait_for_unit("multi-user.target")
    installer.succeed("test -b /dev/vdb")
    installer.succeed("${diskoScript}")

    installer.succeed("test -b /dev/disk/by-partlabel/test-system")

    installer.succeed("mountpoint -q /mnt")
    installer.succeed("mountpoint -q /mnt/nix")
    installer.succeed("mountpoint -q /mnt/persist")
    installer.succeed("mountpoint -q /mnt/boot")
    installer.succeed(
        "${pkgs.nixos-install-tools}/bin/nixos-install "
        "--root /mnt "
        "--system ${targetTopLevel} "
        "--no-channel-copy "
        "--no-root-password "
    )

    installer.succeed("test -L /mnt/nix/var/nix/profiles/system")
    installer.succeed("test -e /mnt/etc/NIXOS")
    installer.succeed("test -e /mnt/boot/loader/loader.conf")
    installer.succeed(
        "test -e /mnt/boot/EFI/BOOT/"
        "BOOT${lib.toUpper pkgs.stdenv.hostPlatform.efiArch}.EFI"
    )
  '';
}
