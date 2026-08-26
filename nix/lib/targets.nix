{
  lib,
  hosts,
  hostNames,
  runtime,
  targetNames,
}:
let
  inherit (runtime) mkRuntimeContexts;
  applyRuntimeContext = hostConfig: runtimeContext: hostConfig // runtimeContext;
  mkHostTargetConfigEntries =
    target:
    lib.concatMap (
      host:
      let
        h = hosts.${host};
      in
      lib.optionals (lib.elem target h.targets) (
        map (
          runtimeContext:
          let
            config = mkHostTargetConfig (applyRuntimeContext h runtimeContext);
          in
          {
            name = config.configName;
            inherit config;
          }
        ) (mkRuntimeContexts h.runtime)
      )
    ) hostNames;
  mkHomeTargetConfig =
    config: accountName:
    let
      account = config.accounts.users.${accountName};
    in
    config
    // {
      configName = targetNames.mkHomeTargetName {
        inherit accountName;
        inherit (config) targetHost themeName sessionName;
        inherit (config.runtime) targetAxes;
      };
      inherit account accountName;
      accountRoles = account.roles;
      effectiveRoles = config.hostRoles ++ account.roles;
      accountVariants = account.variants;
      effectiveVariants = config.hostVariants ++ account.variants;
      variantProfiles =
        config.hostVariants ++ config.themeProfiles ++ config.sessionProfiles ++ account.variants;
    };
  mkHostTargetConfig =
    config:
    config
    // {
      configName = targetNames.mkSystemTargetName {
        inherit (config) targetHost themeName sessionName;
        inherit (config.runtime) targetAxes;
      };
      accountRoles = [ ];
      accountVariants = [ ];
      effectiveRoles = config.hostRoles;
      effectiveVariants = config.hostVariants;
    };
  mkHomeTargetConfigEntries = lib.concatMap (
    host:
    let
      h = hosts.${host};
    in
    lib.optionals (lib.elem "home" h.targets) (
      lib.concatMap (
        accountName:
        let
          account = h.accounts.users.${accountName};
        in
        lib.optionals (lib.elem "home" account.targets) (
          map (
            runtimeContext:
            let
              config = applyRuntimeContext h runtimeContext;
              homeConfig = mkHomeTargetConfig config accountName;
            in
            {
              name = homeConfig.configName;
              config = homeConfig;
            }
          ) (mkRuntimeContexts h.runtime)
        )
      ) h.accountNames
    )
  ) hostNames;
  mkTargetConfigEntries =
    target: if target == "home" then mkHomeTargetConfigEntries else mkHostTargetConfigEntries target;
  assertUniqueTargetNames =
    target: entries:
    let
      names = map (entry: entry.name) entries;
    in
    assert lib.assertMsg (builtins.length (lib.unique names) == builtins.length names)
      "Generated duplicate ${target} target names; check runtime.targetAxes for hidden multi-value axes";
    entries;
  mkTargetConfigs =
    target: mkConf:
    lib.listToAttrs (
      map (entry: {
        inherit (entry) name;
        value = mkConf entry.config;
      }) (assertUniqueTargetNames target (mkTargetConfigEntries target))
    );
  targetConfigNamesForSystem =
    target: system:
    map (entry: entry.name) (
      lib.filter (entry: entry.config.system == system) (mkTargetConfigEntries target)
    );
in
{
  inherit
    mkTargetConfigEntries
    mkTargetConfigs
    targetConfigNamesForSystem
    ;
}
