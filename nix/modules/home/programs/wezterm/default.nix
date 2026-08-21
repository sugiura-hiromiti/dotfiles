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
        terminalProviders =
          let
            customAppIdCommand = "${wezterm} start --class custom.term";
          in
          {
            wezterm = {
              package = pkgs.wezterm;
              command = "${wezterm} start";
              # TODO: search whether I really need to configure appId myself
              appId = "org.wezfurlong.wezterm";
              startupCommand = customAppIdCommand;
              startupAppId = "custom.term";
              keybindCommand = "${customAppIdCommand} --always-new-process";
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
