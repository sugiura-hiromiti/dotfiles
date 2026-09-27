{
  lib,
  pkgs,
}:
{
  source,
  planFile,
  identityPath ? "/etc/dotfiles/identity.json",
}:
pkgs.writeTextFile {
  name = "dotfiles-update";
  executable = true;
  text = ''
    #!${lib.getExe pkgs.nushell} --no-config-file
    const PLAN = "${planFile}"
    const IDENTITY = "${identityPath}"
    const SOURCE = "${source}"
    const GIT = "${lib.getExe pkgs.git}"
    const MKDIR = "${lib.getExe' pkgs.coreutils "mkdir"}"
    ${builtins.readFile ./operation.nu}
    ${builtins.readFile ./update.nu}
  '';
  checkPhase = ''
    UPDATE_SCRIPT="$target" \
    ${lib.getExe pkgs.nushell} --no-config-file --commands \
    'if not (nu-check --debug $env.UPDATE_SCRIPT) { exit 1 }'
  '';
}
