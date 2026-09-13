{
  pkgs,
  lib,
  disko,
  ...
}:
let
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
                disk = "/dev/vdb";
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
  name = "dotfiles.storage-provisioning-vm";
  nodes = {
    machine = {
      virtualisation = {
        emptyDiskImages = [ 1024 ];
      };
    };
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    machine.succeed("test -b /dev/vdb")
    machine.succeed("${diskoScript}")
    machine.succeed("test -b /dev/disk/by-partlabel/test-system")
    machine.succeed(
        "test \"$(blkid -s TYPE -o value /dev/disk/by-partlabel/test-system)\" = btrfs"
    )
    machine.succeed("mkdir -p /run/storage-top")
    machine.succeed(
        "mount -o subvolid=5 /dev/disk/by-partlabel/test-system /run/storage-top"
    )

    machine.succeed(
        "${pkgs.btrfs-progs}/bin/btrfs subvolume show /run/storage-top/@root"
    )
  '';
}
