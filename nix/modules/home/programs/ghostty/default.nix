{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.ghostty;
in
{
  options.dotfiles.programs.ghostty.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the repository-managed Ghostty configuration.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."ghostty" = {
      source = ./config;
      recursive = true;
    };
  };
}
