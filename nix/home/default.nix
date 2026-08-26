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
    ../modules/home
    ./base.nix
  ]
  ++ resolve {
    target = "home";
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
