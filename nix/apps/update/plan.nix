{
  lib,
  pkgs,
  system,
  metadata,
}:
let
  hostNames = builtins.attrNames metadata.hosts;

  mkEntry = path: value: pkgs.writeTextDir path value;
  mkMarker = path: mkEntry path "";
  aliasPairs = lib.concatMap (
    hostName:
    map (alias: {
      name = alias;
      value = hostName;
    }) metadata.hosts.${hostName}.aliases
  ) hostNames;
  aliasNames = map (alias: alias.name) aliasPairs;
  nixosHosts = map (target: target.targetHost) metadata.targets.nixos;
  darwinHosts = map (target: target.targetHost) metadata.targets.darwin;
  systemKindFor =
    hostName:
    if lib.elem hostName nixosHosts then
      "nixos"
    else if lib.elem hostName darwinHosts then
      "darwin"
    else
      null;

  hourName = hour: if hour < 10 then "0${toString hour}" else toString hour;
  themeByHour = lib.listToAttrs (
    map (hour: lib.nameValuePair (hourName hour) (if hour >= 6 && hour < 17 then "light" else "dark")) (
      lib.range 0 23
    )
  );
  targetValue = kind: target: {
    inherit (target) name;
    eval =
      if kind == "home" then
        "homeConfigurations.${builtins.toJSON target.name}.activationPackage.drvPath"
      else if kind == "nixos" then
        "nixosConfigurations.${builtins.toJSON target.name}.config.system.build.toplevel.drvPath"
      else
        "darwinConfigurations.${builtins.toJSON target.name}.system.drvPath";
  };
  targetPath =
    kind: target:
    if kind == "home" then
      [
        target.targetHost
        target.accountName
        target.themeName
        target.sessionName
      ]
    else
      [
        target.targetHost
        target.themeName
        target.sessionName
      ];
  indexTargets =
    kind:
    lib.foldl' lib.recursiveUpdate { } (
      map (
        target: lib.setAttrByPath (targetPath kind target) (targetValue kind target)
      ) metadata.targets.${kind}
    );
  data = {
    inherit system themeByHour;
    aliases = lib.listToAttrs aliasPairs;
    hosts = lib.mapAttrs (hostName: host: {
      defaultSession = host.runtime.defaultSession;
      autoSession = {
        gui = if host.runtime.targetAxes.session then "gui" else host.runtime.defaultSession;
        tty = if host.runtime.targetAxes.session then "tty" else host.runtime.defaultSession;
      };
      systemKind = systemKindFor hostName;
    }) metadata.hosts;
    targets = {
      home = indexTargets "home";
      nixos = indexTargets "nixos";
      darwin = indexTargets "darwin";
    };
  };

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
    mkEntry "targets/home/${target.targetHost}/${target.accountName}/${target.themeName}/${target.sessionName}" target.name
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

{
  inherit data;
  lookup = pkgs.symlinkJoin {
    name = "dotfiles-update-lookup";
    paths =
      aliasEntries ++ hostEntries ++ homeTargetEntries ++ nixosTargetEntries ++ darwinTargetEntries;
  };
}
