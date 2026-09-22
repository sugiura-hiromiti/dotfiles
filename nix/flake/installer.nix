{
  lib,
  nixpkgs,
  self,
  declaredNixosHostsForSystem,
  defaultTarget,
}:
{
  perSystem =
    { system, ... }:
    {
      packages = lib.listToAttrs (
        map (hostConfig: {
          name = "installer-${hostConfig.host}";
          value =
            (import ../installer/iso.nix {
              inherit nixpkgs system;
              source = self.outPath;
              inherit (hostConfig) host facterRelativePath;
              target = defaultTarget "nixos" hostConfig.host;
              primaryAccount = hostConfig.accounts.primary;
            }).config.system.build.isoImage;
        }) (declaredNixosHostsForSystem system)
      );
    };
}
