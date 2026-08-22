{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.kitty;
  kitty = lib.getExe pkgs.kitty;
in
{
  options = {
    dotfiles = {
      programs = {
        kitty = {
          enable = lib.mkEnableOption "kitty terminal emulator";
        };
      };
    };
  };
  config = lib.mkMerge [
    {
      dotfiles = {
        terminalProviders = {
          kitty = {
            package = pkgs.kitty;
            appId = "kitty";
            mkCommand =
              {
                appId ? null,
                wait ? false,
              }:
              lib.escapeShellArgs (
                [ kitty ]
                ++ lib.optionals (appId != null) [
                  "--app-id"
                  appId
                ]
              );
          };
        };
      };
    }
    (lib.mkIf cfg.enable {
      xdg.configFile."kitty" = {
        source = ./config;
        recursive = true;
      };
    })
  ];
}
