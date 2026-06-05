{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.libskk;
in
{
  options.dotfiles.programs.libskk.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the repository-managed libskk configuration.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."libskk" = {
      source = ./config;
      recursive = true;
    };
  };
}
