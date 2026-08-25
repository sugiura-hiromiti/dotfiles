{
  lib,
  system ? builtins.currentSystem,
  host ? null,
  effectiveRoles ? [ ],
  hostVariants ? [ ],
  accountVariants ? [ ],
  themeProfiles ? [ ],
  sessionProfiles ? [ ],
  ...
}:
let
  platform = lib.last (lib.splitString "-" system);
  resolve = import ../lib/resolve-profiles.nix { inherit lib; };
in
{
  imports = [
    ./base.nix
  ]
  ++ resolve {
    baseDir = ../.;
    target = "darwin";
    inherit
      platform
      system
      host
      effectiveRoles
      hostVariants
      accountVariants
      themeProfiles
      sessionProfiles
      ;
  };
}
