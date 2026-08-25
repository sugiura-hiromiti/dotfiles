{
  lib,
  system,
  hosts,
  hostNames,
  mkTargetConfigEntries,
}:
let
  currentHostNames = lib.filter (hostName: hosts.${hostName}.system == system) hostNames;
  targetEntriesForSystem =
    target: lib.filter (entry: entry.config.system == system) (mkTargetConfigEntries target);
  projectTarget = entry: {
    inherit (entry) name;
    inherit (entry.config) targetHost themeName sessionName;
  };
  projectHomeTarget = entry: projectTarget entry // { inherit (entry.config) accountName; };
in
{
  hosts = lib.listToAttrs (
    map (
      hostName:
      let
        host = hosts.${hostName};
      in
      {
        name = host.targetHost;
        value = {
          aliases = host.matchNames;
          runtime = {
            inherit (host.runtime)
              defaultSession
              targetAxes
              ;
          };
        };
      }
    ) currentHostNames
  );
  targets = {
    home = map projectHomeTarget (targetEntriesForSystem "home");
    nixos = map projectTarget (targetEntriesForSystem "nixos");
    darwin = map projectTarget (targetEntriesForSystem "darwin");
  };
}
