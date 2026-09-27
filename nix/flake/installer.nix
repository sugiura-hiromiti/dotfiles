{
  lib,
  nixpkgs,
  self,
  declaredNixosTargetEntries,
  declaredNixosHostsForSystem,
  defaultTarget,
}:
{
  perSystem =
    { system, ... }:
    let
      entries = lib.filter (entry: entry.config.system == system) declaredNixosTargetEntries;
      installers = lib.listToAttrs (
        map (entry: {
          name = "installer-${entry.name}";
          value =
            (import ../installer/iso.nix {
              inherit nixpkgs system;
              source = self.outPath;
              inherit (entry.config) host facterRelativePath;
              target = entry.name;
              primaryAccount = entry.config.accounts.primary;
            }).config.system.build.isoImage;
        }) entries
      );
      selectionAlias = hostConfig: deploymentName: {
        name = "installer-selection-${hostConfig.host}--deployment-${deploymentName}";
        value =
          installers."installer-${
            defaultTarget {
              target = "nixos";
              hostName = hostConfig.host;
              inherit deploymentName;
            }
          }";
      };
      aliases = lib.concatMap (
        hostConfig:
        map (selectionAlias hostConfig) hostConfig.deploymentNames
        ++ lib.optional (hostConfig.defaultDeploymentName != null) {
          name = "installer-selection-${hostConfig.host}";
          inherit (selectionAlias hostConfig hostConfig.defaultDeploymentName) value;
        }
      ) (declaredNixosHostsForSystem system);
    in
    {
      packages = installers // lib.listToAttrs aliases;
    };
}
