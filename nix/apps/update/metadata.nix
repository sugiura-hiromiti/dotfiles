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
          hasSessionAxis = host.runtime.targetAxes.session;
          inherit (host) systemTargetKind;
        };
      }
    ) currentHostNames
  );
  targets = {
    home = targetEntriesForSystem "home";
    nixos = targetEntriesForSystem "nixos";
    darwin = targetEntriesForSystem "darwin";
  };
}
