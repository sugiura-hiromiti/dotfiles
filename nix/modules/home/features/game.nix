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
    programs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "prismlauncher" ];
      description = "Repository program modules enabled with the game feature";
    };
  };

  config = lib.mkIf cfg.enable {
    dotfiles.programs = lib.genAttrs cfg.programs (_: {
      enable = lib.mkDefault true;
    });
  };
}
