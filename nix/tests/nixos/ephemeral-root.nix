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

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    machine.succeed("test -b /dev/vdb")
  '';
}
