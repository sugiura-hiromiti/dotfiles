{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.alacritty;
in
{
  options.dotfiles.programs.alacritty.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the repository-managed Alacritty configuration.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."alacritty" = {
      source = ./config;
      recursive = true;
    };
  };
}
