{
  lib,
  pkgs,
  formatter,
}:
let
  fixScript = pkgs.writeShellApplication {
    name = "dotfiles-fix";

    text = ''
      if ! root="$(${lib.getExe pkgs.jujutsu} root)"; then
        echo "dotfiles-fix requires a Jujutsu workspace." >&2
        echo "Initialize this checkout with: jj git init --colocate" >&2
        exit 1
      fi
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
