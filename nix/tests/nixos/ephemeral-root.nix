{
  pkgs,
  lib,
  disko,
  ...
}:
let
  # Test fixture only.
  filesystemUuid = "11111111-2222-4333-8444-555555555555";
  disk = "/dev/vdb";
  btrfsDevice = "/dev/disk/by-partlabel/test-system";
  diskoSystem = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      disko.nixosModules.disko
      ../../modules/nixos/features/storage
      {
        dotfiles = {
          features = {
            storage = {
              inherit filesystemUuid;
              partitionLabel = "test-system";
              provisioning = {
                enable = true;
                inherit disk;
              };
            };
          };
        };
      }
    ];
  };
  diskoScript = diskoSystem.config.system.build.diskoScript;
in
pkgs.testers.runNixOSTest {
  name = "dotfiles.ephemeral-root";
  nodes = {
    machine = { ... }: {
      imports = [ ../../modules/nixos/features/impermanence/ephemeral-root.nix ];
      # TODO: this code have to be removed finally
      system = {
        extraDependencies = [ diskoScript ];
      };
      specialisation = {
        ephemeral-root = {
          configuration = {
            dotfiles = {
              features = {
                ephemeralRoot = {
                  enable = true;
                  device = btrfsDevice;
                  subvolume = "@root";
                };
              };
            };
          };
        };
      };
      virtualisation = {
        emptyDiskImages = [ 1024 ];
        useBootLoader = true;
        useEFIBoot = true;
      };
      environment = {
        systemPackages = [ pkgs.btrfs-progs ];
      };
      boot = {
        loader = {
          systemd-boot = {
            enable = true;
          };
        };
      };
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    machine.succeed("test -b /dev/vdb")
    machine.succeed("${diskoScript}")

    machine.succeed("mkdir -p /run/storage-top")
    machine.succeed(
        "mount -o subvolid=5 "
        "${btrfsDevice} "
        "/run/storage-top"
    )
    machine.succeed(
        "${pkgs.btrfs-progs}/bin/btrfs subvolume show /run/storage-top/@root"
    )

    marker = "/run/storage-top/@root/before-reset";
    machine.succeed(f"touch {marker}")
    machine.succeed(f"test -e {marker}")
    machine.succeed("umount /run/storage-top")
    machine.succeed(
        "/run/current-system/specialisation/ephemeral-root/"
        "bin/switch-to-configuration boot"
    )
    machine.shutdown()
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("mkdir -p /run/storage-top")
    machine.succeed(
        "mount -o subvolid=5 "
        "${btrfsDevice} "
        "/run/storage-top"
    )

    machine.fail(
        "test -e /run/storage-top/@root/before-reset"
    )

    machine.succeed(
        "${pkgs.btrfs-progs}/bin/btrfs subvolume show "
        "/run/storage-top/@root"
    )
  '';
}
