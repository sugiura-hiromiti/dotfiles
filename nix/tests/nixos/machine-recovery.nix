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
      virtualisation = {
        emptyDiskImages = [ 128 ];
        fileSystems = {
          "/" = {
            device = "none";
            fsType = "btrfs";
            options = [
              "mode=0755"
              "noatime"
            ];
            neededForBoot = true;
          };
          "/persist" = {
            device = "/dev/vdb";
            fsType = "ext4";
            autoFormat = true;
            neededForBoot = true;
          };
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
  testScript = ''
    nixos.start()
    nixos.wait_for_unit("multi-user.target")
    nixos.shutdown()
  '';
}
