{
  config,
  lib,
  pkgs,
  reaperFlake,
  ...
}:
{
  config = lib.mkIf config.dotfiles.programs.reaper.enable {
    programs = {
      reaper = {
        theme = {
          packages = [ reaperFlake.packages.${pkgs.stdenv.hostPlatform.system}.reaclassical-theme ];
          active = "ReaClassical WaveColors Light.ReaperThemeZip";
        };
      };
    };
  };
}
