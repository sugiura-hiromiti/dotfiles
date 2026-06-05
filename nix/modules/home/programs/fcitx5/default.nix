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
  options.dotfiles.programs.fcitx5.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the repository-managed Fcitx 5 configuration.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile = lib.listToAttrs (
      map (name: {
        name = "fcitx5/${name}";
        value.source = ./config + "/${name}";
      }) files
    );
  };
}
