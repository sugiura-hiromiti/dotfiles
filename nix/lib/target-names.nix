# Public flake target name schema. Keep all generated target names here so
# runtime, target enumeration, and helper apps cannot drift apart.
let
  mkSystemTargetName =
    {
      targetHost,
      themeName,
      sessionName,
    }:
    "${targetHost}--theme-${themeName}--session-${sessionName}";

  mkHomeTargetName =
    {
      targetHost,
      accountName,
      themeName,
      sessionName,
    }:
    "${targetHost}--account-${accountName}--theme-${themeName}--session-${sessionName}";
in
{
  inherit mkHomeTargetName mkSystemTargetName;

  examples = {
    home = mkHomeTargetName {
      targetHost = "HOST";
      accountName = "ACCOUNT";
      themeName = "THEME";
      sessionName = "SESSION";
    };
    system = mkSystemTargetName {
      targetHost = "HOST";
      themeName = "THEME";
      sessionName = "SYSTEM_SESSION";
    };
  };
}
