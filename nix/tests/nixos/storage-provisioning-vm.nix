{
  pkgs,
  lib,
  disko,
  ...
}:
let
  filesystemUuid = "11111111-2222-4333-8444-555555555555";
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
              inherit filesystemUuid;
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

    machine.succeed(
        "test \"$(blkid -s UUID -o value /dev/disk/by-partlabel/test-system)\" "
        "= ${filesystemUuid}"
    )

    machine.succeed("mkdir -p /run/storage-top")
    machine.succeed(
        "mount -o subvolid=5 /dev/disk/by-partlabel/test-system /run/storage-top"
    )

    machine.succeed(
        "${pkgs.btrfs-progs}/bin/btrfs subvolume show /run/storage-top/@root"
    )
    machine.succeed(
        "${pkgs.btrfs-progs}/bin/btrfs subvolume show /run/storage-top/@nix"
    )
    machine.succeed(
        "${pkgs.btrfs-progs}/bin/btrfs subvolume show /run/storage-top/@persist"
    )
    esp = machine.succeed(
        "lsblk -rno PATH,PARTTYPE /dev/vdb "
        "| grep -i c12a7328-f81f-11d2-ba4b-00a0c93ec93b "
        "| awk '{print $1}'"
    ).strip()

    assert esp != "", "EFI System Partition not found"
    machine.succeed(
        f'test "$(blkid -s TYPE -o value {esp})" = vfat'
    )
  '';
}
