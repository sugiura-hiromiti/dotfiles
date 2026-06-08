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
  getRuntimeProfiles =
    kind: name: context:
    assert lib.assertMsg (context ? profiles) "Runtime ${kind} '${name}' context must define profiles";
    assert lib.assertMsg (builtins.isList context.profiles)
      "Runtime ${kind} '${name}' context profiles must be a list";
    context.profiles;
  mkRuntimeConfig =
    hostConfig: themeName: sessionName:
    let
      themeContext = getRuntimeContext "theme" themeName runtimeContexts.themes;
      sessionContext = getRuntimeContext "session" sessionName runtimeContexts.sessions;
      themeProfiles = getRuntimeProfiles "theme" themeName themeContext;
      sessionProfiles = getRuntimeProfiles "session" sessionName sessionContext;
      runtimeConfig = hostConfig.runtime // {
        profiles = {
          theme = themeProfiles;
          session = sessionProfiles;
        };
      };
    in
    hostConfig
    // {
      configName = targetNames.mkSystemTargetName {
        inherit themeName sessionName;
        inherit (hostConfig) targetHost;
        inherit (hostConfig.runtime) targetAxes;
      };
      inherit (themeContext) theme;
      inherit (sessionContext) session hasGui;
      inherit themeName sessionName;
      inherit themeProfiles sessionProfiles;
      has_gui = if sessionContext.hasGui then "true" else "false";
      hostVariants = hostConfig.variants;
      inherit (hostConfig) variants;
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
