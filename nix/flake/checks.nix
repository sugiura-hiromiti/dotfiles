{
  home-manager,
  reaper-flake,
  lib,
  self,
  disko,
  preservation,
  nixpkgs,
  nixos,
  darwin,
  mkTargetConfigEntries,
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
          reaper-flake
          nixosTargetEntries
          preservation
          lib
          pkgs
          self
          disko
          nixpkgs
          nixos
          darwin
          ;
        deploymentNixosTargetEntries = mkReadyTargetConfigEntries "nixos";
        deploymentDarwinTargetEntries = mkTargetConfigEntries "darwin";
        formattingCheck = config.treefmt.build.check self;
        targetConfigNames = {
          home = targetConfigNamesForSystem "home" system;
          nixos = targetConfigNamesForSystem "nixos" system;
          darwin = targetConfigNamesForSystem "darwin" system;
        };
      };
    };
}
