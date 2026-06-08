{ lib, ... }:
let
  attrNames = attrs: lib.sort lib.lessThan (builtins.attrNames attrs);
  importNixFiles =
    dir:
    let
      entries = builtins.readDir dir;
    in
    map (name: dir + "/${name}") (
      builtins.filter (name: entries.${name} == "regular" && lib.hasSuffix ".nix" name) (
        attrNames entries
      )
    );
  importProgramModules =
    dir:
    let
      entries = builtins.readDir dir;
    in
    map (name: dir + "/${name}") (
      builtins.filter (
        name:
        let
          path = dir + "/${name}";
        in
        entries.${name} == "directory" && builtins.pathExists (path + "/default.nix")
      ) (attrNames entries)
    );
in
{
  imports = importNixFiles ./base ++ importNixFiles ./features ++ importProgramModules ./programs;
}
