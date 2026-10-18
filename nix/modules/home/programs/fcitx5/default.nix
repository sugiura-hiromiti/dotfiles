{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.fcitx5;
in
{
  options.dotfiles.programs.fcitx5 = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to install additional Fcitx 5 user packages.";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional Fcitx 5 user packages to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = cfg.packages;
  };
}
