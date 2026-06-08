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
    ../modules/nixos
    ./base.nix
  ]
  ++ resolve {
    baseDir = ../.;
    target = "nixos";
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
