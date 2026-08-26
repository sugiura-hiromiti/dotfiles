{
  lib,
  system ? builtins.currentSystem,
  os,
  host ? null,
  effectiveRoles ? [ ],
  hostVariants ? [ ],
  accountVariants ? [ ],
  themeProfiles ? [ ],
  sessionProfiles ? [ ],
  ...
}:
let
  resolve = import ../lib/resolve-profiles.nix { inherit lib; };
in
{
  imports = [
    ./base.nix
  ]
  ++ resolve {
    target = "darwin";
    inherit
      system
      os
      host
      effectiveRoles
      hostVariants
      accountVariants
      themeProfiles
      sessionProfiles
      ;
  };
}
