{
  lib,
  pkgs,
  metadata,
}:
let
  hostNames = builtins.attrNames metadata.hosts;
  mkEntry = path: value: pkgs.writeTextDir path value;
  # TODO: 何故必要？markerが必要になる設計は美しいといえるだろうか
  mkMarker = path: mkEntry path "";
  aliasPairs = lib.concatMap (
    hostName:
    map (alias: {
      name = alias;
      value = hostName;
    }) metadata.hosts.${hostName}.aliases
  ) hostNames;
  aliasNames = map (alias: alias.name) aliasPairs;
  aliasEntries = map (alias: mkEntry "aliases/${alias.name}" alias.value) aliasPairs;
  hostEntries = lib.concatMap (
    hostName:
    let
      host = metadata.hosts.${hostName};
    in
    [
      (mkEntry "hosts/${hostName}/default-session" host.runtime.defaultSession)
    ]
    ++ lib.optional host.runtime.targetAxes.session (mkMarker "hosts/${hostName}/session-axis")
    ++ map (account: mkMarker "hosts/${hostName}/accounts/${account}") host.accounts
    ++ map (theme: mkMarker "hosts/${hostName}/themes/${theme}") host.runtime.themes
    ++ map (session: mkMarker "hosts/${hostName}/sessions/${session}") host.runtime.sessions
  ) hostNames;
  homeTargetEntries = map (
    target:
    mkEntry "targets/home/${target.targetHost}/${target.accontName}/${target.themeName}/${target.sessionName}" target.name
  ) metadata.targets.home;
  mkSystemTargetEntry =
    kind: target:
    mkEntry "targets/${kind}/${target.targetHost}/${target.themeName}/${target.sessionName}" target.name;
  nixosTargetEntries = map (mkSystemTargetEntry "nixos") metadata.targets.nixos;
  darwinTargetEntries = map (mkSystemTargetEntry "darwin") metadata.targets.darwin;
in
assert lib.assertMsg (
  builtins.length aliasNames == builtins.length (lib.unique aliasNames)
) "host aliases must be unique";

pkgs.symlinkJoin {
  name = "dotfiles-update-lookup";
  paths =
    aliasEntries ++ hostEntries ++ homeTargetEntries ++ nixosTargetEntries ++ darwinTargetEntries;
}
