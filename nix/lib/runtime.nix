{
  lib,
  runtimeContexts,
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
  mkRuntimeContext =
    themeName: sessionName:
    let
      themeContext = getRuntimeContext "theme" themeName runtimeContexts.themes;
      sessionContext = getRuntimeContext "session" sessionName runtimeContexts.sessions;
      themeProfiles = getRuntimeProfiles "theme" themeName themeContext;
      sessionProfiles = getRuntimeProfiles "session" sessionName sessionContext;
    in
    {
      inherit (themeContext) theme;
      inherit (sessionContext) session hasGui;
      inherit
        themeName
        sessionName
        themeProfiles
        sessionProfiles
        ;
    };
  mkRuntimeContexts =
    runtime:
    lib.concatMap (
      themeName: map (sessionName: mkRuntimeContext themeName sessionName) runtime.sessions
    ) runtime.themes;
in
{
  inherit
    mkRuntimeContexts
    ;
}
