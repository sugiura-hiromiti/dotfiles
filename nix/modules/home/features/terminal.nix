{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.terminal;
in
{
  options.dotfiles.features.terminal = {
    enable = lib.mkEnableOption "terminal tools";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.wezterm;
      defaultText = lib.literalExpression "pkgs.wezterm";
      description = "Terminal package used by desktop features.";
    };

    command = lib.mkOption {
      type = lib.types.str;
      default = "${lib.getExe cfg.package} start";
      defaultText = lib.literalExpression ''"${lib.getExe config.dotfiles.features.terminal.package} start"'';
      description = "Terminal command used by features that need to launch a terminal.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
