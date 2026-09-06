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
    nixos.shutdown()
  '';
}
