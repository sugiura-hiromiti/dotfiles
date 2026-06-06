{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.niri;
in
{
  options.dotfiles.programs.niri.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to install the repository-managed niri configuration.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."niri" = {
      source = ./config;
      recursive = true;
    };
  };
}
