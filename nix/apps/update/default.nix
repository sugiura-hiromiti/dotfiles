# TODO: policyをさらにNix側へ寄せ、update.nuをruntime orchestration中心に縮小する。
# update.nuは50行以下を目標にする。
{
  lib,
  pkgs,
  system,
  hosts,
  hostNames,
  mkTargetConfigEntries,
}:
let
  plan = import ./plan.nix {
    inherit
      lib
      system
      hosts
      hostNames
      mkTargetConfigEntries
      ;
  };
  planFile = pkgs.writeText "dotfiles-update-plan.json" (builtins.toJSON plan.data);
  updateScript = pkgs.writeTextFile {
    name = "dotfiles-update";
    executable = true;
    text = ''
      #!${lib.getExe pkgs.nushell} --no-config-file
      const PLAN = "${planFile}"
      ${builtins.readFile ./update.nu}
    '';
    checkPhase = ''
      UPDATE_SCRIPT="$target" \
      ${lib.getExe pkgs.nushell} --no-config-file --commands \
      'if not (nu-check --debug $env.UPDATE_SCRIPT) { exit 1 }'
    '';
  };
in
{
  type = "app";
  meta.description = "Update flake inputs and switch the current host configuration";
  program = toString updateScript;
}
