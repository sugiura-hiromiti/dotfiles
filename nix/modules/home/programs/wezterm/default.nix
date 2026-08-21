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
  config = lib.mkIf cfg.enable {
    dotfiles = {
      terminalProviders =
        let
          customAppIdCommand = "${wezterm} start --class custom.term";
        in
        {
          wezterm = {
            package = pkgs.wezterm;
            command = "${wezterm} star";
            # TODO: search whether I really need to configure appId myself
            appId = "org.wezfurlong.wezterm";
            startupCommand = customAppIdCommand;
            startupAppId = "custom.term";
            keybindCommand = "${customAppIdCommand} --always-new-process";
          };
        };
    };
    xdg = {
      configFile = {
        "wezterm" = {
          source = ./config;
          recursive = true;
        };
      };
    };
  };
}
