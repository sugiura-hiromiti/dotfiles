{
  lib,
  system,
  os,
  host ? null,
  variantProfiles ? [ ],
  ...
}:
let
  resolve = import ../lib/resolve-profiles.nix { inherit lib; };
in
{
  imports = [
    ../modules/nixos
    ./base.nix
  ]
  ++ resolve {
    target = "nixos";
    inherit
      system
      os
      host
      variantProfiles
      ;
  };
}
