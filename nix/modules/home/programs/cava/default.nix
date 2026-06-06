{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.cava;
in
{
  options.dotfiles.programs.cava.enable = lib.mkOption {
    type = lib.types.bool;
    default = pkgs.stdenv.isLinux;
    defaultText = lib.literalExpression "pkgs.stdenv.isLinux";
    description = "Whether to enable CAVA.";
  };

  config = lib.mkIf cfg.enable {
    programs.cava.enable = true;
  };
}
