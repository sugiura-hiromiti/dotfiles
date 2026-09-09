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
              "/nix" = {
                device = "/dev/vdb";
                fsType = "btrfs";
                options = [ "subvol=@nix" ];
                neededForBoot = true;
              };
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
                ephemeralRoot = {
                  enable = true;
                  device = "/dev/vdb";
                };
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
    in
    "";
}
