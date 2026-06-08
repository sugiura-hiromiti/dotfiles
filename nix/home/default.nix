{
  lib,
  system,
  host ? null,
  roles ? [ ],
  variants ? [ ],
  themeProfiles ? [ ],
  sessionProfiles ? [ ],
  hostVariants ? variants,
  accountVariants ? [ ],
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
      roles
      themeProfiles
      sessionProfiles
      accountVariants
      ;
    variants = hostVariants;
  };
}
