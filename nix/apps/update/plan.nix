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
  updateHosts = lib.listToAttrs (
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
  updateTargets = {
    home = targetEntriesForSystem "home";
    nixos = targetEntriesForSystem "nixos";
    darwin = targetEntriesForSystem "darwin";
  };

  hostNames = builtins.attrNames updateHosts;

  aliasPairs = lib.concatMap (
    hostName:
    map (alias: {
      name = alias;
      value = hostName;
    }) updateHosts.${hostName}.aliases
  ) hostNames;
  aliasNames = map (alias: alias.name) aliasPairs;
  hourName = hour: if hour < 10 then "0${toString hour}" else toString hour;
  themeByHour = lib.listToAttrs (
    map (hour: lib.nameValuePair (hourName hour) (if hour >= 6 && hour < 17 then "light" else "dark")) (
      lib.range 0 23
    )
  );
  targetValue = kind: entry: {
    inherit (entry) name;
    inherit (actions.${kind}) authorize switch;
    eval =
      if kind == "home" then
        "homeConfigurations.${builtins.toJSON entry.name}.activationPackage.drvPath"
      else if kind == "nixos" then
        "nixosConfigurations.${builtins.toJSON entry.name}.config.system.build.toplevel.drvPath"
      else
        "darwinConfigurations.${builtins.toJSON entry.name}.system.drvPath";
  };
  targetPath =
    kind: entry:
    let
      config = entry.config;
    in
    if kind == "home" then
      [
        config.targetHost
        config.accountName
        config.themeName
        config.sessionName
      ]
    else
      [
        config.targetHost
        config.themeName
        config.sessionName
      ];

  targetPathKey = kind: entry: builtins.toJSON (targetPath kind entry);
  assertUniqueTargetPaths =
    kind: targets:
    let
      paths = map (targetPathKey kind) targets;
    in
    assert lib.assertMsg (
      builtins.length paths == builtins.length (lib.unique paths)
    ) "duplicate ${kind} update target paths";
    targets;

  indexTargets =
    kind:
    lib.foldl' lib.recursiveUpdate { } (
      map (entry: lib.setAttrByPath (targetPath kind entry) (targetValue kind entry)) (
        assertUniqueTargetPaths kind updateTargets.${kind}
      )
    );

  homeTargets = indexTargets "home";
  nixosTargets = indexTargets "nixos";
  darwinTargets = indexTargets "darwin";
  systemTargets = {
    nixos = nixosTargets;
    darwin = darwinTargets;
  };

  actions = {
    home = {
      authorize = [ ];
      switch = [
        "nix"
        "run"
        "nixpkgs#home-manager"
        "--"
        "switch"
        "--flake"
      ];
    };
    nixos = {
      authorize = [
        "sudo"
        "-v"
      ];
      switch = [
        "sudo"
        "nixos-rebuild"
        "switch"
        "--flake"
      ];
    };
    darwin = {
      authorize = [
        "sudo"
        "-v"
      ];
      switch = [
        "sudo"
        "-H"
        "nix"
        "--extra-experimental-features"
        "nix-command flakes"
        "run"
        "nix-darwin"
        "--"
        "switch"
        "--flake"
      ];
    };
  };
  commands = {
    update = [
      "nix"
      "flake"
      "update"
    ];
    eval = [
      "nix"
      "eval"
      "--raw"
    ];
  };
  data = {
    inherit
      system
      themeByHour
      commands
      ;
    aliases = lib.listToAttrs aliasPairs;
    hosts = lib.mapAttrs (hostName: host: {
      inherit (host) defaultSession;
      autoSession = {
        gui = if host.hasSessionAxis then "gui" else host.defaultSession;
        tty = if host.hasSessionAxis then "tty" else host.defaultSession;
      };
      home = lib.attrByPath [ hostName ] { } homeTargets;
      system =
        if host.systemTargetKind == null then
          null
        else
          {
            kind = host.systemTargetKind;
            targets = lib.attrByPath [ hostName ] { } systemTargets.${host.systemTargetKind};
          };
    }) updateHosts;
  };
in
assert lib.assertMsg (
  builtins.length aliasNames == builtins.length (lib.unique aliasNames)
) "host aliases must be unique";

{
  inherit data;
}
