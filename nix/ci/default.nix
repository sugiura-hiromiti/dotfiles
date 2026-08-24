{
  hosts,
  lib,
  mkTargetConfigEntries,
}:
let
  defaultTarget =
    target: hostName:
    let
      host = hosts.${hostName};
      matches = lib.filter (
        entry:
        entry.config.host == hostName
        && entry.config.themeName == host.runtime.defaultTheme
        && entry.config.sessionName == host.runtime.defaultSession
        && (target != "home" || entry.config.accountName == host.primaryAccountName)
      ) (mkTargetConfigEntries target);
    in
    assert lib.assertMsg (
      builtins.length.matches == 1
    ) "Expected exactly one default ${target} target for ${hostName}";
    (lib.head matches).name;
in
{ }
