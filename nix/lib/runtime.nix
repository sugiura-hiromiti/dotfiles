{
  lib,
  runtimeContexts,
  targetNames,
}:
let
  getRuntimeContext =
    kind: name: contexts:
    assert lib.assertMsg (builtins.hasAttr name contexts) "Unknown runtime ${kind}: ${name}";
    contexts.${name};
  mkRuntimeConfig =
    hostConfig: themeName: sessionName:
    let
      themeContext = getRuntimeContext "theme" themeName runtimeContexts.themes;
      sessionContext = getRuntimeContext "session" sessionName runtimeContexts.sessions;
      runtimeVariants = themeContext.variants ++ sessionContext.variants;
      runtimeConfig = hostConfig.runtime // {
        variants = runtimeVariants;
      };
    in
    hostConfig
    // {
      configName = targetNames.mkSystemTargetName {
        inherit themeName sessionName;
        inherit (hostConfig) targetHost;
      };
      inherit (themeContext) theme;
      inherit (sessionContext) session hasGui;
      inherit themeName sessionName;
      has_gui = if sessionContext.hasGui then "true" else "false";
      variants = hostConfig.variants ++ runtimeVariants;
      runtime = runtimeConfig;
    };
  mkDefaultRuntimeConfig =
    hostConfig:
    mkRuntimeConfig hostConfig hostConfig.runtime.defaultTheme hostConfig.runtime.defaultSession;
  mkRuntimeConfigs =
    hostConfig:
    lib.concatMap (
      themeName:
      map (sessionName: mkRuntimeConfig hostConfig themeName sessionName) hostConfig.runtime.sessions
    ) hostConfig.runtime.themes;
in
{
  inherit
    getRuntimeContext
    mkDefaultRuntimeConfig
    mkRuntimeConfig
    mkRuntimeConfigs
    ;
}
