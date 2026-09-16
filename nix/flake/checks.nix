{
  lib,
  self,
  disko,
  preservation,
  targetConfigNamesForSystem,
}:
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = import ../checks.nix {
        inherit
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
