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
        ini = {
          files = {
            "reaper-themeconfig.ini" = { };
          };
        };
        theme = {
          packages = [ reaperFlake.packages.${pkgs.system}.smooth6-theme ];
          active = "Smooth_6.ReaperThemeZip";
        };
      };
    };
  };
}
