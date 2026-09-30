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
      installerPackages = map (entry: {
        name = "installer-${entry.name}";
        value =
          (import ../installer/iso.nix {
            inherit nixpkgs system;
            source = self.outPath;
            inherit (entry.config) host facterRelativePath;
            target = entry.name;
            primaryAccount = entry.config.accounts.primary;
          }).config.system.build.isoImage.overrideAttrs
            (previous: {
              passthru = (previous.passthru or { }) // {
                installerIdentity = {
                  inherit (entry.config) host;
                  deployment = entry.config.deploymentName;
                  target = entry.name;
                };
              };
            });
      }) entries;
      installers = lib.listToAttrs installerPackages;
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
      packageEntries = installerPackages ++ aliases;
      packageNames = map (entry: entry.name) packageEntries;
      duplicateNames = lib.filter (name: lib.count (candidate: candidate == name) packageNames > 1) (
        lib.unique packageNames
      );
    in
    {
      packages =
        assert lib.assertMsg (
          duplicateNames == [ ]
        ) "Installer package names collide: ${lib.concatStringsSep ", " duplicateNames}";
        lib.listToAttrs packageEntries;
    };
}
