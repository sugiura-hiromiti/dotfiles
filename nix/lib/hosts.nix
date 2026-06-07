{
  lib,
  hostDir,
  runtimeContexts,
}:
let
  defaultRuntime = {
    themes = lib.attrNames runtimeContexts.themes;
    sessions = lib.attrNames runtimeContexts.sessions;
    defaultTheme = runtimeContexts.defaults.theme;
    defaultSession = runtimeContexts.defaults.session;
  };
  hostEntries = builtins.readDir hostDir;
  hostNames = lib.attrNames (lib.filterAttrs (_: type: type == "directory") hostEntries);
  mkHost =
    host:
    let
      meta = import (hostDir + "/${host}/meta.nix");
      inherit (meta) system;
      # host: profile registry key, derived from the directory name.
      # targetHost: public flake target prefix used by switch/update commands.
      # hostName: OS/network hostname configured inside the target system.
      hostName = meta.hostName or host;
      targetHost = meta.targetHost or host;
      roles = meta.roles or [ ];
      variants = meta.variants or [ ];
      targets = meta.targets or [ "home" ];
      accountsMeta =
        assert lib.assertMsg (meta ? accounts) "Host '${host}' must define accounts";
        meta.accounts;
      rawAccounts =
        assert lib.assertMsg (accountsMeta ? users) "Host '${host}' accounts must define users";
        accountsMeta.users;
      accountNames =
        assert lib.assertMsg (rawAccounts != { }) "Host '${host}' accounts.users must not be empty";
        lib.attrNames rawAccounts;
      primaryAccountName =
        assert lib.assertMsg (accountsMeta ? primary) "Host '${host}' accounts.primary must be set";
        accountsMeta.primary;
      normalizeAccount =
        name: account:
        account
        // {
          inherit name;
          description = account.description or name;
          extraGroups = account.extraGroups or [ ];
          homeDirectory = account.homeDirectory or null;
          roles = account.roles or [ ];
          targets = account.targets or [ "home" ];
          uid = account.uid or null;
          variants = account.variants or [ ];
        };
      accounts = {
        primary = primaryAccountName;
        users = builtins.mapAttrs normalizeAccount rawAccounts;
      };
      primaryAccount =
        assert lib.assertMsg (builtins.hasAttr primaryAccountName accounts.users)
          "Host '${host}' accounts.primary '${primaryAccountName}' is not defined in accounts.users";
        accounts.users.${primaryAccountName};
      matchNames = lib.unique (
        [
          host
          targetHost
        ]
        ++ lib.optional (hostName != host) hostName
        ++ (meta.aliases or [ ])
      );
      runtimeMeta = meta.runtime or { };
      runtime = {
        themes = runtimeMeta.themes or defaultRuntime.themes;
        sessions = runtimeMeta.sessions or defaultRuntime.sessions;
        defaultTheme = runtimeMeta.defaultTheme or defaultRuntime.defaultTheme;
        defaultSession = runtimeMeta.defaultSession or defaultRuntime.defaultSession;
      };
    in
    {
      inherit
        host
        system
        hostName
        targetHost
        accounts
        accountNames
        primaryAccountName
        primaryAccount
        matchNames
        roles
        variants
        targets
        runtime
        ;
    };
  hosts = builtins.listToAttrs (
    map (host: {
      name = host;
      value = mkHost host;
    }) hostNames
  );
  targetHostNames = map (host: hosts.${host}.targetHost) hostNames;
in
assert lib.assertMsg (
  builtins.length (lib.unique targetHostNames) == builtins.length targetHostNames
) "Host targetHost values must be unique";
{
  inherit
    defaultRuntime
    hosts
    hostNames
    targetHostNames
    ;
}
