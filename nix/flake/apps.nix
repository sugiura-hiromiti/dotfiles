{
  lib,
  self,
  hosts,
  hostNames,
  mkTargetConfigEntries,
}:
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      apps = {
        build-installer = import ../apps/build-installer {
          inherit lib pkgs;
        };
        update = import ../apps/update {
          inherit
            lib
            pkgs
            system
            hosts
            hostNames
            mkTargetConfigEntries
            ;
          source = self.outPath;
        };
        fix = import ../apps/fix {
          inherit lib pkgs;
          formatter = config.treefmt.build.wrapper;
        };
      };
    };
}
