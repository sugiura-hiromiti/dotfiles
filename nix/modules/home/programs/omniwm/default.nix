{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.omniwm;
in
{
  options.dotfiles.programs.omniwm.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to install the repository-managed OmniWM configuration.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."omniwm/settings.toml".source = ./config/settings.toml;
  };
}
