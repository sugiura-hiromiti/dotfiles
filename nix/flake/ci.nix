{
  lib,
  hosts,
  defaultTarget,
  readyNixosTargetEntries,
  actions-nix,
}:
let
  ciConfig = import ../ci {
    inherit
      hosts
      lib
      defaultTarget
      readyNixosTargetEntries
      ;
  };
in
{
  perSystem =
    { pkgs, ... }:
    let
      actionsEval = actions-nix.lib.evalModule pkgs ciConfig;
    in
    {
      packages.render-workflows = actionsEval.config.build.renderWorkflows;
    };
}
