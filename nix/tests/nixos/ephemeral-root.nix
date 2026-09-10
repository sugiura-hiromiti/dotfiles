{ pkgs, ... }:
let
  # Test fixture only.
  btrfsDevice = "/dev/vdb";
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

  testScript =
    { nodes, ... }:
    let
      ephemeralSystem = nodes.machine.specialisation.ephemeral-root.configuration.system.build.toplevel;
    in
    ''
      machine.start()
      machine.wait_for_unit("multi-user.target")

      # Prepare fixture.
      machine.succeed("mkfs.btrfs -f ${btrfsDevice}")
      machine.succeed("mkdir -p /mnt/fixture")
      machine.succeed("mount ${btrfsDevice} /mnt/fixture")
      machine.succeed("btrfs subvolume create /mnt/fixture/@root")
      machine.succeed("touch /mnt/fixture/@root/old-root-marker")
      machine.succeed("umount /mnt/fixture")

      # Next boot uses ephemeral-root.
      machine.succeed(
          "${ephemeralSystem}/bin/switch-to-configuration boot"
      )
      machine.succeed("sync")
      machine.crash()

      machine.wait_for_unit("multi-user.target")

      # @root should have been deleted and recreated.
      machine.succeed("mkdir -p /mnt/verify")
      machine.succeed("mount ${btrfsDevice} /mnt/verify")
      machine.succeed("btrfs subvolume show /mnt/verify/@root")
      machine.fail("test -e /mnt/verify/@root/old-root-marker")
      machine.succeed("umount /mnt/verify")
    '';
}
