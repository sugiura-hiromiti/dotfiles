{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.fcitx5;
  files = [
    "config"
    "profile"
    "conf/classicui.conf"
    "conf/clipboard.conf"
    "conf/imselector.conf"
    "conf/keyboard.conf"
    "conf/mozc.conf"
    "conf/notifications.conf"
    "conf/skk.conf"
    "conf/wayland.conf"
    "conf/waylandim.conf"
  ];
in
{
  options.dotfiles.programs.fcitx5 = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to install the repository-managed Fcitx 5 configuration.";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional Fcitx 5 packages installed with the repository-managed configuration.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = cfg.packages;

    xdg.configFile = lib.listToAttrs (
      map (name: {
        name = "fcitx5/${name}";
        value.source = ./config + "/${name}";
      }) files
    );
  };
}
