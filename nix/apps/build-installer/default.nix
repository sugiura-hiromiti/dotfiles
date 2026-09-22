{
  lib,
  pkgs,
  nixExecutable ? lib.getExe pkgs.nix,
  jjExecutable ? lib.getExe pkgs.jujutsu,
  cpExecutable ? lib.getExe' pkgs.coreutils "cp",
  mktempExecutable ? lib.getExe' pkgs.coreutils "mktemp",
  rmExecutable ? lib.getExe' pkgs.coreutils "rm",
}:
let
  buildInstaller = pkgs.writeTextFile {
    name = "dotfiles-build-installer";
    executable = true;
    text = ''
      #!${lib.getExe pkgs.nushell} --no-config-file
      const NIX = "${nixExecutable}"
      const JJ = "${jjExecutable}"
      const CP = "${cpExecutable}"
      const MKTEMP = "${mktempExecutable}"
      const RM = "${rmExecutable}"
      ${builtins.readFile ./build.nu}
    '';
    checkPhase = ''
      BUILD_INSTALLER_SCRIPT="$target" \
      ${lib.getExe pkgs.nushell} --no-config-file --commands \
      'if not (nu-check --debug $env.BUILD_INSTALLER_SCRIPT) { exit 1 }'
    '';
  };
in
{
  type = "app";
  meta.description = "Build installation media from the current versioned dotfiles";
  program = toString buildInstaller;
}
