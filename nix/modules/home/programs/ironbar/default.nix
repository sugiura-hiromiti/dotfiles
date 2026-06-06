{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.ironbar;
in
{
  options.dotfiles.programs.ironbar.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to install the repository-managed Ironbar configuration.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."ironbar" = {
      source = ./config;
      recursive = true;
    };
  };
}
