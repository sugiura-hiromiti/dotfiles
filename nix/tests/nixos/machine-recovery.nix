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
          configuration = { };
        };
      };
      # dotfiles = {
      #   features = {
      #     preservation = {
      #       enable = true;
      #     };
      #   };
      # };
    };
  };
  testScript = ''
    nixos.start()
    nixos.wait_for_unit("multi-user.target")
    nixos.shutdown()
  '';
}
