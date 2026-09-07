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
      boot = {
        loader = {
          systemd-boot = {
            enable = true;
          };
          efi = {
            canTouchEfiVariables = true;
          };
        };
      };
      virtualisation = {
        emptyDiskImages = [ 512 ];
        mountHostNixStore = true;
        useBootLoader = true;
        useEFIBoot = true;
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
  testScript =
    { nodes, ... }:
    let
      recoverySystem = nodes.nixos.specialisation.machine-recovery.configuration.system.build.toplevel;
    in
    ''
      nixos.start()
      nixos.wait_for_unit("multi-user.target")

      nixos.succeed("mkfs.btrfs /dev/vdb")

      with subtest("recovery disk has btrfs layout"):
          nixos.succeed("btrfs filesystem show /dev/vdb")

      nixos.succeed("mkdir -p /mnt/recovery")
      nixos.succeed("mount /dev/vdb /mnt/recovery")

      nixos.succeed("btrfs subvolume create /mnt/recovery/@root")
      nixos.succeed("btrfs subvolume create /mnt/recovery/@persist")

      with subtest("recovery subvolume exists"):
          nixos.succeed("btrfs subvolume show /mnt/recovery/@root")
          nixos.succeed("btrfs subvolume show /mnt/recovery/@persist")

      nixos.succeed("umount /mnt/recovery")

      with subtest("boots recovery specialisation"):
          nixos.succeed("${recoverySystem}/bin/switch-to-configuration boot")
          nixos.succeed("sync")
          nixos.crash()
          nixos.wait_for_unit("multi-user.target")

      with subtest("write persistent and ephemeral probes"):
          nixos.succeed(
              "echo persistent > /var/lib/nixos/machine-recovery-test"
          )
          nixos.succeed(
              "echo ephemeral > /etc/machine-recovery-ephemeral"
          )

      with subtest("persistent probe reaches persist subvolume"):
          nixos.succeed(
              "grep -q persistent /persist/var/lib/nixos/machine-recovery-test"
          )

      with subtest("ephemeral probe lives only on root"):
          nixos.succeed(
              "grep -q ephemeral /etc/machine-recovery-ephemeral"
          )
          nixos.fail(
              "test -e /persist/etc/machine-recovery-ephemeral"
          )

      with subtest("recovery filesystem layout is mounted"):
          nixos.succeed('test "$(findmnt -n -o FSTYPE /)" = btrfs')
          nixos.succeed('test "$(findmnt -n -o FSROOT /)" = /@root')

          nixos.succeed("mountpoint /persist")
          nixos.succeed('test "$(findmnt -n -o FSTYPE /persist)" = btrfs')
          nixos.succeed('test "$(findmnt -n -o FSROOT /persist)" = /@persist')
    '';
}
