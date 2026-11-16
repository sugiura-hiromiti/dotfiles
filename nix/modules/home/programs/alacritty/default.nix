{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.alacritty;
  alacritty = lib.getExe config.dotfiles.terminalProviders.alacritty.package;
in
{
  options = {
    dotfiles = {
      programs = {
        alacritty = {
          enable = lib.mkEnableOption "alacritty terminal emulator";
        };
      };
    };
  };
  config = lib.mkMerge [
    {
      dotfiles = {
        terminalProviders = {
          alacritty = {
            package = pkgs.alacritty;
            appId = "Alacritty";
            mkCommand =
              {
                appId ? null,
                withCommand ? false,
                ...
              }:
              lib.escapeShellArgs (
                [ alacritty ]
                ++ lib.optionals (appId != null) [
                  "--class"
                  appId
                ]
                ++ lib.optional withCommand "-e"
              );
          };

        };
      };
    }
    (lib.mkIf cfg.enable {
      xdg.configFile."alacritty" = {
        source = ./config;
        recursive = true;
      };
    })
  ];
}
