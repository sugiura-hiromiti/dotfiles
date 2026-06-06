{
  config,
  lib,
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
    xdg.configFile."wezterm" = {
      source = ./config;
      recursive = true;
    };
  };
}
