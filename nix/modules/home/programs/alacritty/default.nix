{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.alacritty;
  alacritty = lib.getExe pkgs.alacritty;
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
            mkCommand =
              {
                appId ? null,
                wait ? false,
              }:
              lib.escapeShellArgs (
                [ alacritty ]
                ++ lib.optionals (appId != null) [
                  "--class"
                  appId
                ]
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
