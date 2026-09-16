{
  mkTargetConfigs,
  home,
  nixos,
  darwin,
}:
{
  flake = {
    homeConfigurations = mkTargetConfigs "home" home.build;
    nixosConfigurations = mkTargetConfigs "nixos" nixos.build;
    darwinConfigurations = mkTargetConfigs "darwin" darwin.build;
  };
}
