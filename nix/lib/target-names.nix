{ lib }:

# Public flake target name schema. Keep all generated target names here so
# runtime, target enumeration, and helper apps cannot drift apart.
let
  mkRuntimeSegments =
    {
      targetAxes,
      themeName,
      sessionName,
    }:
    lib.optional targetAxes.theme "theme-${themeName}"
    ++ lib.optional targetAxes.session "session-${sessionName}";

  mkSystemTargetName =
    {
      targetHost,
      targetAxes ? {
        theme = true;
        session = true;
      },
      themeName ? null,
      sessionName ? null,
    }:
    lib.concatStringsSep "--" (
      [ targetHost ]
      ++ mkRuntimeSegments {
        inherit
          sessionName
          targetAxes
          themeName
          ;
      }
    );

  mkHomeTargetName =
    {
      targetHost,
      accountName,
      targetAxes ? {
        theme = true;
        session = true;
      },
      themeName ? null,
      sessionName ? null,
    }:
    lib.concatStringsSep "--" (
      [
        targetHost
        "account-${accountName}"
      ]
      ++ mkRuntimeSegments {
        inherit
          sessionName
          targetAxes
          themeName
          ;
      }
    );
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
