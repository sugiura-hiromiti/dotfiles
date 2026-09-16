{
  lib,
  nix,
  nix-agent,
}:
let
  resolveProfiles = import ../lib/resolve-profiles.nix { inherit lib; };
  profileModules =
    target: config:
    resolveProfiles {
      inherit target;
      inherit (config)
        system
        os
        host
        variantProfiles
        ;
    };
  commonSpecialArgs =
    config:
    {
      inherit (config)
        accounts
        configName
        hasGui
        host
        hostName
        session
        system
        systemTargetKind
        os
        targetHost
        theme
        ;
    }
    // lib.optionalAttrs (config ? account) {
      inherit (config) account;
    }
    // lib.optionalAttrs (config ? accountName) {
      inherit (config) accountName;
    };
  systemSpecialArgs =
    config:
    commonSpecialArgs config
    // {
      nixAgentPackage = nix-agent.packages.${config.system}.default;
      nixPackage = nix.packages.${config.system}.default;
    };
in
{
  inherit profileModules commonSpecialArgs systemSpecialArgs;
}
