{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.kitty;
in
{
  options.dotfiles.programs.kitty.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the repository-managed Kitty configuration.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."kitty" = {
      source = ./config;
      recursive = true;
    };
  };
}
