{
  lib,
  system ? builtins.currentSystem,
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
    ./base.nix
  ]
  ++ resolve {
    baseDir = ../.;
    target = "darwin";
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
