{
  pkgs,
  lib,
  disko,
  ...
}:
let
  # Test fixture only.
  btrfsDevice = "/dev/vdb";
  diskoSystem = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      disko.nixosModules.disko
      ../../modules/nixos/features/storage
      {
        dotfiles = {
          features = {
            storage = {
              partitionLabel = "test-system";
              provisioning = {
                enable = true;
                disk = btrfsDevice;
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
        emptyDiskImages = [ 512 ];
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
        "/dev/disk/by-partlabel/test-system "
        "/run/storage-top"
    )
    machine.succeed(
        "${pkgs.btrfs-progs}/bin/btrfs subvolume show /run/storage-top/@root"
    )
  '';
}
