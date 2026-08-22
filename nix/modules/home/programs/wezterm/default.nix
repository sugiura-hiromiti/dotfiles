{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.wezterm;
  wezterm = lib.getExe pkgs.wezterm;
in
{
  options = {
    dotfiles = {
      programs = {
        wezterm = {
          enable = lib.mkEnableOption "wezterm terminal emulator";
        };
      };
    };
  };
  config = lib.mkMerge [
    {
      dotfiles = {
        terminalProviders = {
          wezterm = {
            package = pkgs.wezterm;
            mkCommand =
              {
                appId ? null,
                wait ? false,
              }:
              lib.escapeShellArgs (
                [
                  wezterm
                  "start"
                ]
                ++ lib.optional wait "--always-new-process"
                ++ lib.optionals (appId != null) [
                  "--class"
                  appId
                ]
              );
          };
        };
        features = {
          terminal = {
            role = {
              transient = {
                appId = "dotfiles.terminal.transient";
              };
            };
          };
        };
      };
    }
    (lib.mkIf cfg.enable {
      xdg = {
        configFile = {
          "wezterm" = {
            source = ./config;
            recursive = true;
          };
        };
      };
    })
  ];
}
