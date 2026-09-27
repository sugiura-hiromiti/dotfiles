{
  lib,
  pkgs,
  nixpkgs,
  nixos,
  darwin,
  nixosTargetEntries,
  darwinTargetEntries,
}:
let
  probe = {
    environment.etc."dotfiles/deployment-probe".text = "selected-deployment";
  };
  withDeploymentModules =
    config: modules:
    config
    // {
      deployment = config.deployment // {
        inherit modules;
      };
    };
  checkTarget =
    builder: entry:
    let
      targetConfig = withDeploymentModules entry.config [ probe ];
      built = builder.build targetConfig;
      identity = builtins.fromJSON built.config.environment.etc."dotfiles/identity.json".text;
    in
    assert lib.assertMsg (lib.elem probe (
      builder.modulesFor targetConfig
    )) "System target '${entry.name}' must compose the selected deployment module directly";
    assert lib.assertMsg (
      built.config.environment.etc."dotfiles/deployment-probe".text == "selected-deployment"
    ) "System target '${entry.name}' must evaluate its selected deployment module";
    assert lib.assertMsg (
      identity == {
        host = entry.config.host;
        deployment = entry.config.deploymentName;
      }
    ) "System target '${entry.name}' identity must contain exactly its logical host and deployment";
    true;
  priorityTarget = withDeploymentModules (builtins.head nixosTargetEntries).config [
    { services.qemuGuest.enable = true; }
  ];
  sharedDefault = {
    services.qemuGuest.enable = lib.mkDefault false;
  };
  evaluatePriority =
    modules:
    (nixpkgs.lib.nixosSystem {
      inherit (priorityTarget) system;
      inherit modules;
    }).config.services.qemuGuest.enable;
in
assert lib.assertMsg (nixosTargetEntries != [ ]) "Deployment checks require a real NixOS target";
assert lib.assertMsg (darwinTargetEntries != [ ]) "Deployment checks require a real Darwin target";
assert lib.all (checkTarget nixos) nixosTargetEntries;
assert lib.all (checkTarget darwin) darwinTargetEntries;
assert evaluatePriority ([ sharedDefault ] ++ priorityTarget.deployment.modules);
assert evaluatePriority (priorityTarget.deployment.modules ++ [ sharedDefault ]);
pkgs.runCommandLocal "deployment-model-test" { } ''touch "$out"''
