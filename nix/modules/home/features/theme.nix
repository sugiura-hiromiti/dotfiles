{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.features.theme;
in
{
  options.dotfiles.features.theme = {
    enable = lib.mkEnableOption "Home Manager theme integration";

    accent = lib.mkOption {
      type = lib.types.str;
      default = "blue";
      description = "Catppuccin accent for Home Manager integrations.";
    };

    cursorAccent = lib.mkOption {
      type = lib.types.str;
      default = "sky";
      description = "Catppuccin cursor accent.";
    };

    autoEnable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to automatically enable supported Catppuccin integrations.";
    };

    gtkIconAccent = lib.mkOption {
      type = lib.types.str;
      default = "sapphire";
      description = "Catppuccin GTK icon accent.";
    };

    yaziAccent = lib.mkOption {
      type = lib.types.str;
      default = "blue";
      description = "Catppuccin Yazi accent.";
    };
  };

  config = lib.mkIf cfg.enable {
    catppuccin = {
      inherit (cfg) autoEnable;
      enable = lib.mkDefault true;
      accent = lib.mkDefault cfg.accent;

      cursors = {
        enable = lib.mkDefault true;
        accent = lib.mkDefault cfg.cursorAccent;
      };

      gtk.icon.accent = lib.mkDefault cfg.gtkIconAccent;
      yazi.accent = lib.mkDefault cfg.yaziAccent;
    };
  };
}
