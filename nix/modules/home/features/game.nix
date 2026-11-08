{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.features.game;
in
{
  options.dotfiles.features.game = {
    enable = lib.mkEnableOption "game related tools";
    prismlauncher.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable PrismLauncher with the game feature";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.prismlauncher.enable) {
    dotfiles.programs.prismlauncher.enable = lib.mkDefault true;
  };
}
