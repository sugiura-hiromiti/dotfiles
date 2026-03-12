{
  lib,
  system,
  host ? null,
  user,
  roles ? [ ],
  variants ? [ ],
  ...
}:
let
  platform = lib.last (lib.splitString "-" system);
  resolve = import ../lib/resolve-profiles.nix { inherit lib; };
in
{
  imports =
    [ ./base.nix ]
    ++ resolve {
      baseDir = ../.;
      target = "home";
      inherit platform system host user roles variants;
    };
}
