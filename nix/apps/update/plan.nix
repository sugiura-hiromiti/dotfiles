{
  lib,
  system,
  metadata,
}:
let
  hostNames = builtins.attrNames metadata.hosts;

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
    action = kind;
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
      actions
      ;
    aliases = lib.listToAttrs aliasPairs;
    hosts = lib.mapAttrs (hostName: host: {
      inherit (host) defaultSession;
      autoSession = {
        gui = if host.targetAxes then "gui" else host.defaultSession;
        tty = if host.targetAxes then "tty" else host.defaultSession;
      };
      systemKind = systemKindFor hostName;
    }) metadata.hosts;
    targets = {
      home = indexTargets "home";
      nixos = indexTargets "nixos";
      darwin = indexTargets "darwin";
    };
  };
in
assert lib.assertMsg (
  builtins.length aliasNames == builtins.length (lib.unique aliasNames)
) "host aliases must be unique";

{
  inherit data;
}
