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

      ({ modulesPath, ... }: {
        imports = [ (modulesPath + "/testing/test-instrumentation.nix") ];
      })

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
                disk = "/dev/vda";
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
    target = {
      virtualisation = {
        fileSystems = {
          "/" = {
            device = "/dev/disk/by-partlabel/unused-test-root";
            fsType = "ext4";
          };
        };
        diskImage = "./target.qcow2";
        useBootLoader = true;
        useEFIBoot = true;
        useDefaultFilesystems = false;
        efi = {
          keepVariables = false;
        };
      };
    };
    installer = {
      virtualisation = {
        diskImage = "./target.qcow2";
        diskSize = 4096;
        additionalPaths = [ targetTopLevel ];
        rootDevice = "/dev/vdb";
        emptyDiskImages = [ 1024 ];
        fileSystems = {
          "/" = {
            autoFormat = true;
          };
        };
      };
    };
  };
  testScript = ''
    installer.start()
    installer.wait_for_unit("multi-user.target")
    installer.succeed("test -b /dev/vda")
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

    installer.succeed("umount -R /mnt")
    installer.succeed("sync")
    installer.shutdown()

    target.state_dir = installer.state_dir
    target.start(allow_reboot=True)
    target.wait_for_unit("multi-user.target")

    target.succeed("test \"$(findmnt -n -o FSTYPE /)\" = btrfs")
    target.succeed("test \"$(findmnt -n -o FSROOT /)\" = /@root")

    target.succeed("test \"$(findmnt -n -o FSROOT /nix)\" = /@nix")
    target.succeed("test \"$(findmnt -n -o FSROOT /persist)\" = /@persist")

    target.succeed("echo disposable > /impermanence-root-marker")
    target.succeed("echo persistent > /persist/impermanence-persist-marker")
    target.succeed("sync")

    target.reboot()
    target.wait_for_unit("multi-user.target")

    target.succeed("test ! -e /impermanence-root-marker")
    target.succeed(
        "test \"$(cat /persist/impermanence-persist-marker)\" = persistent"
    )
  '';
}
