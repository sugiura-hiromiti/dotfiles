{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.fish;
in
{
  options.dotfiles.programs.fish.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the repository-managed Fish configuration.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile = {
      "fish/config.fish".source = ./config/config.fish;
      "fish/conf.d" = {
        source = ./config/conf.d;
        recursive = true;
      };
      "fish/functions" = {
        source = ./config/functions;
        recursive = true;
      };
      "fish/completions" = {
        source = ./config/completions;
        recursive = true;
      };
    };
  };
}
