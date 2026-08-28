{
  lib,
  pkgs,
  formatter,
}:
let
  fixScript = pkgs.writeShellApplication {
    name = "dotfiles-fix";

    text = ''
      root="$(${lib.getExe pkgs.jujutsu} root)"
      cd "$root"

      ${lib.getExe pkgs.deadnix} --edit .
      ${lib.getExe pkgs.statix} fix .
      ${formatter}/bin/treefmt
    '';
  };
in
{
  type = "app";
  meta.description = "Automatically fix lint and formatting issues";
  program = lib.getExe fixScript;
}
