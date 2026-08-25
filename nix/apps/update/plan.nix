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
          inherit (host) primaryAccountName systemTargetKind;
        };
      }
    ) currentHostNames
  );
  # TODO: Treat account -> host as an update-time selection hint, not yet as
  # a domain invariant. Revisit ambiguity handling after host/account semantics
  # are formally defined in the host model
  primaryHostPairs = map (hostName: {
    name = updateHosts.${hostName}.primaryAccountName;
    value = hostName;
  }) updateHostNames;
  indexedTargets = lib.mapAttrs (kind: _: indexTargets kind) targetPolicies;

  updateHostNames = builtins.attrNames updateHosts;

  aliasPairs = lib.concatMap (
    hostName:
    map (alias: {
      name = alias;
      value = hostName;
    }) updateHosts.${hostName}.aliases
  ) updateHostNames;
  aliasNames = map (alias: alias.name) aliasPairs;
  hourName = hour: if hour < 10 then "0${toString hour}" else toString hour;
  themeByHour = lib.listToAttrs (
    map (hour: lib.nameValuePair (hourName hour) (if hour >= 6 && hour < 17 then "light" else "dark")) (
      lib.range 0 23
    )
  );
  targetPolicies = {
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

      eval = name: "homeConfigurations.${builtins.toJSON name}.activationPackage.drvPath";

      path = config: [
        config.targetHost
        config.accountName
        config.themeName
        config.sessionName
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

      eval = name: "nixosConfigurations.${builtins.toJSON name}.config.system.build.toplevel.drvPath";

      path = config: [
        config.targetHost
        config.themeName
        config.sessionName
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

      eval = name: "darwinConfigurations.${builtins.toJSON name}.system.drvPath";

      path = config: [
        config.targetHost
        config.themeName
        config.sessionName
      ];
    };
  };
  targetValue =
    kind: entry:
    let
      policy = targetPolicies.${kind};
    in
    {
      inherit (entry) name;
      inherit (policy) authorize switch;
      eval = policy.eval entry.name;
    };
  targetPath = kind: entry: targetPolicies.${kind}.path entry.config;

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
        assertUniqueTargetPaths kind (targetEntriesForSystem kind)
      )
    );

  data = {
    inherit
      themeByHour
      ;
    aliases = lib.listToAttrs aliasPairs;
    defaultHosts = lib.listToAttrs primaryHostPairs;
    hosts = lib.mapAttrs (hostName: host: {
      inherit (host) defaultSession;
      autoSession = {
        gui = if host.hasSessionAxis then "gui" else host.defaultSession;
        tty = if host.hasSessionAxis then "tty" else host.defaultSession;
      };
      home = lib.attrByPath [ hostName ] { } indexedTargets.home;
      system =
        if host.systemTargetKind == null then
          null
        else
          {
            kind = host.systemTargetKind;
            targets = lib.attrByPath [ hostName ] { } indexedTargets.${host.systemTargetKind};
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
