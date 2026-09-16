{
  lib,
  self,
  disko,
  preservation,
  mkTargetConfigEntries,
  targetConfigNamesForSystem,
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      nixosTargetEntries = lib.filter (entry: entry.config.system == system) (
        mkTargetConfigEntries "nixos"
      );
    in
    {

      checks = import ../checks.nix {
        inherit
          nixosTargetEntries
          preservation
          lib
          pkgs
          self
          disko
          ;
        targetConfigNames = {
          home = targetConfigNamesForSystem "home" system;
          nixos = targetConfigNamesForSystem "nixos" system;
          darwin = targetConfigNamesForSystem "darwin" system;
        };
      };
    };
}
