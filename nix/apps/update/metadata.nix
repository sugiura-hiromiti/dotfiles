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
          defaultSession = host.runtime.defaultSession;
          # TODO: targetAxesってそもそも何？
          hasSessionAxis = host.runtime.targetAxes.session;
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
