{
  lib,
  hostDir,
  runtimeContexts,
}:
let
  defaultRuntime = {
    themes = [ runtimeContexts.defaults.theme ];
    sessions = [ runtimeContexts.defaults.session ];
    defaultTheme = runtimeContexts.defaults.theme;
    defaultSession = runtimeContexts.defaults.session;
    targetAxes = {
      theme = false;
      session = false;
    };
  };
  runtimeAxisNames = [
    "theme"
    "session"
  ];
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
      runtimeTargetAxesMeta = runtimeMeta.targetAxes or { };
      unknownTargetAxes = lib.filter (axis: !(lib.elem axis runtimeAxisNames)) (
        lib.attrNames runtimeTargetAxesMeta
      );
      rawRuntimeThemes = runtimeMeta.themes or defaultRuntime.themes;
      rawRuntimeSessions = runtimeMeta.sessions or defaultRuntime.sessions;
      runtimeThemes =
        assert lib.assertMsg (rawRuntimeThemes != [ ]) "Host '${host}' runtime.themes must not be empty";
        lib.unique rawRuntimeThemes;
      runtimeSessions =
        assert lib.assertMsg (
          rawRuntimeSessions != [ ]
        ) "Host '${host}' runtime.sessions must not be empty";
        lib.unique rawRuntimeSessions;
      unknownThemes = lib.filter (
        themeName: !(builtins.hasAttr themeName runtimeContexts.themes)
      ) runtimeThemes;
      unknownSessions = lib.filter (
        sessionName: !(builtins.hasAttr sessionName runtimeContexts.sessions)
      ) runtimeSessions;
      runtimeDefaultTheme =
        runtimeMeta.defaultTheme or (
          if lib.elem defaultRuntime.defaultTheme runtimeThemes then
            defaultRuntime.defaultTheme
          else
            lib.head runtimeThemes
        );
      runtimeDefaultSession =
        runtimeMeta.defaultSession or (
          if lib.elem defaultRuntime.defaultSession runtimeSessions then
            defaultRuntime.defaultSession
          else
            lib.head runtimeSessions
        );
      targetAxes = {
        theme = runtimeTargetAxesMeta.theme or defaultRuntime.targetAxes.theme;
        session = runtimeTargetAxesMeta.session or defaultRuntime.targetAxes.session;
      };
      runtime = {
        inherit targetAxes;
        themes = runtimeThemes;
        sessions = runtimeSessions;
        defaultTheme =
          assert lib.assertMsg (lib.elem runtimeDefaultTheme runtimeThemes)
            "Host '${host}' runtime.defaultTheme '${runtimeDefaultTheme}' must be one of runtime.themes";
          runtimeDefaultTheme;
        defaultSession =
          assert lib.assertMsg (lib.elem runtimeDefaultSession runtimeSessions)
            "Host '${host}' runtime.defaultSession '${runtimeDefaultSession}' must be one of runtime.sessions";
          runtimeDefaultSession;
      };
    in
    assert lib.assertMsg (unknownTargetAxes == [ ])
      "Host '${host}' runtime.targetAxes contains unknown axes: ${lib.concatStringsSep ", " unknownTargetAxes}";
    assert lib.assertMsg (unknownThemes == [ ])
      "Host '${host}' runtime.themes contains unknown themes: ${lib.concatStringsSep ", " unknownThemes}";
    assert lib.assertMsg (unknownSessions == [ ])
      "Host '${host}' runtime.sessions contains unknown sessions: ${lib.concatStringsSep ", " unknownSessions}";
    assert lib.assertMsg (
      targetAxes.theme || builtins.length runtimeThemes == 1
    ) "Host '${host}' has multiple runtime.themes, so runtime.targetAxes.theme must be true";
    assert lib.assertMsg (
      targetAxes.session || builtins.length runtimeSessions == 1
    ) "Host '${host}' has multiple runtime.sessions, so runtime.targetAxes.session must be true";
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
