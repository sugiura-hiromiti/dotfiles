{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.darwin.fonts;
in
{
  options.dotfiles.darwin.fonts.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install baseline fonts on Darwin hosts.";
  };

  config = lib.mkIf cfg.enable {
    fonts.packages = [
      pkgs.maple-mono.NF-CN
    ];
  };
}
