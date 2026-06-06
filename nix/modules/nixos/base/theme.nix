{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.nixos.theme;
in
{
  options.dotfiles.nixos.theme.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure baseline system theming.";
  };

  config = lib.mkIf cfg.enable {
    catppuccin = {
      enable = lib.mkDefault true;
      autoEnable = lib.mkDefault true;
      fcitx5 = {
        accent = lib.mkDefault "yellow";
        enableRounded = lib.mkDefault true;
      };
    };
  };
}
