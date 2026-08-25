{
  lib,
  system,
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
    ../modules/home
    ./base.nix
  ]
  ++ resolve {
    baseDir = ../.;
    target = "home";
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
