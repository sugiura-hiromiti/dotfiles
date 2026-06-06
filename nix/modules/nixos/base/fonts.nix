{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.nixos.fonts;
in
{
  options.dotfiles.nixos.fonts.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure baseline fonts.";
  };

  config = lib.mkIf cfg.enable {
    fonts = {
      packages = with pkgs; [
        maple-mono.NF-CN
        noto-fonts-color-emoji
      ];

      fontDir.enable = lib.mkDefault true;

      fontconfig.defaultFonts = {
        serif = [ "Maple Mono NF CN" ];
        sansSerif = [ "Maple Mono NF CN" ];
        monospace = [ "Maple Mono NF CN" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
