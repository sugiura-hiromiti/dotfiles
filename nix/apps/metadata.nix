{
  lib,
  system,
  hosts,
  hostNames,
  mkTargetConfigEntries,
}:
let
  currentHosts = lib.filter (hostName: hosts.${hostName}.system == system) hostNames;
  targetEntriesForSystem =
    target: lib.filter (entry: entry.config.system == system) (mkTargetConfigEntries);
in
{
  hosts = lib.listToAttrs (
    map (
      hostName:
      let
        host = host.${hostName};
      in
      {
        name = host.targetHost;
        value = {
          aliases = host.matchNames;
          runtime = {
            inherit (host.runtime)
              defaultSession
              sessions
              targetAxes
              themes
              ;
          };
        };
      }
    ) currentHosts
  );
  targets = {
    home = targetEntriesForSystem "home";
    nixos = targetEntriesForSystem "nixos";
    darwin = targetEntriesForSystem "darwin";
  };
}
