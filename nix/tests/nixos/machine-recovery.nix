{
  pkgs,
  recoveryTarget,
  nixosModulesFor,
  systemSpecialArgs,
}:
pkgs.testers.runNixOSTest {
  name = "dotfiles.machine-recovery";
  node = {
    pkgsReadOnly = false;
    specialArgs = systemSpecialArgs recoveryTarget.config;
  };
  nodes = {
    nixos = {
      imports = nixosModulesFor recoveryTarget.config;
      environment = {
        systemPackages = [ pkgs.btrfs-progs ];
      };
      virtualisation = {
        emptyDiskImages = [ 512 ];
        mountHostNixStore = true;
      };
      specialisation = {
        machine-recovery = {
          configuration = {
            virtualisation = {
              rootDevice = "/dev/vdb";
            };
            fileSystems = pkgs.lib.mkVMOverride {
              "/" = {
                fsType = pkgs.lib.mkForce "btrfs";
                options = [ "subvol=@root" ];
              };
              "/persist" = {
                device = "/dev/vdb";
                fsType = "btrfs";
                options = [ "subvol=@persist" ];
                neededForBoot = true;
              };
            };
            dotfiles = {
              features = {
                preservation = {
                  enable = true;
                };
              };
            };
          };
        };
      };
    };
  };
  testScript = ''
    nixos.start()
    nixos.wait_for_unit("multi-user.target")

    nixos.succeed("mkfs.btrfs /dev/vdb")

    with subtest("recovery disk has btrfs layout"):
        nixos.succeed("btrfs filesystem show /dev/vdb")

    nixos.succeed("mkdir -p /mnt/recovery")
    nixos.succeed("mount /dev/vdb /mnt/recovery")

    nixos.succeed("btrfs subvolume create /mnt/recovery/@root")
    nixos.succeed("btrfs subvolume create /mnt/recovery/@persist")

    with subtest("root subvolume exists"):
        nixos.succeed("btrfs subvolume show /mnt/recovery/@root")
        nixos.succeed("btrfs subvolume show /mnt/recovery/@persist")
  '';
}
