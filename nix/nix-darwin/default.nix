{
  lib,
  system,
  os,
  host ? null,
  hostVariants ? [ ],
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
      hostVariants
      themeProfiles
      sessionProfiles
      ;
  };
}
