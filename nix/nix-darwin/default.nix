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
    ./base.nix
  ]
  ++ resolve {
    target = "darwin";
    inherit
      system
      os
      host
      variantProfiles
      ;
  };
}
