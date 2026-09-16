{
  lib,
  hosts,
  mkTargetConfigEntries,
  actions-nix,
}:
let
  ciConfig = import ../ci {
    inherit hosts lib mkTargetConfigEntries;
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
