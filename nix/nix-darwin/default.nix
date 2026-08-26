{
  lib,
  system,
  os,
  host ? null,
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
      hostVariants
      accountVariants
      themeProfiles
      sessionProfiles
      ;
  };
}
