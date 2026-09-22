{
  home-manager,
  lib,
  self,
  disko,
  preservation,
  nixpkgs,
  mkReadyTargetConfigEntries,
  targetConfigNamesForSystem,
}:
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      nixosTargetEntries = lib.filter (entry: entry.config.system == system) (
        mkReadyTargetConfigEntries "nixos"
      );
    in
    {

      checks = import ../checks.nix {
        inherit
          home-manager
          nixosTargetEntries
          preservation
          lib
          pkgs
          self
          disko
          nixpkgs
          ;
        formattingCheck = config.treefmt.build.check self;
        targetConfigNames = {
          home = targetConfigNamesForSystem "home" system;
          nixos = targetConfigNamesForSystem "nixos" system;
          darwin = targetConfigNamesForSystem "darwin" system;
        };
      };
    };
}
