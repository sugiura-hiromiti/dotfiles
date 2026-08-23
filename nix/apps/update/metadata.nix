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
  projectTarget =
    entry:
    {
      inherit (entry) name;
      inherit (entry.config) targetHost themeName sessionName;
    }
    # TODO: なぜ必要か調べたい
    // lib.optionalAttrs (entry.config ? accountName) {
      inherit (entry.config) accountName;
    };
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
          accounts = host.accountNames;
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
    ) currentHostNames
  );
  targets = {
    home = map projectTarget (targetEntriesForSystem "home");
    nixos = map projectTarget (targetEntriesForSystem "nixos");
    darwin = map projectTarget (targetEntriesForSystem "darwin");
  };
}
