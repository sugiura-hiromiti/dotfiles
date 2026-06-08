{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.wezterm;
in
{
  options.dotfiles.programs.wezterm.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to install the repository-managed WezTerm configuration.";
  };

  config = lib.mkIf cfg.enable {
    dotfiles.features.terminal = {
      package = lib.mkDefault pkgs.wezterm;
      command = lib.mkDefault "${lib.getExe pkgs.wezterm} start";
      appId = lib.mkDefault "org.wezfurlong.wezterm";
      startupAppId = lib.mkDefault "custom.term";
      startupCommand = lib.mkDefault "${lib.getExe pkgs.wezterm} start --class custom.term";
      keybindCommand = lib.mkDefault "${lib.getExe pkgs.wezterm} start --class custom.term --always-new-process";
    };

    xdg.configFile."wezterm" = {
      source = ./config;
      recursive = true;
    };
  };
}
