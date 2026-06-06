{
  config,
  lib,
  pkgs,
  system,
  ...
}:
let
  cfg = config.dotfiles.features.sessionGui;
in
{
  options.dotfiles.features.sessionGui = {
    enable = lib.mkEnableOption "graphical session user packages";

    xwaylandSatellite.package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.xwayland-satellite;
      defaultText = lib.literalExpression "pkgs.xwayland-satellite";
      description = "xwayland-satellite package to install for Wayland sessions.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasSuffix "-linux" system;
        message = "dotfiles.features.sessionGui is Linux-only.";
      }
    ];

    home.packages = [
      cfg.xwaylandSatellite.package
    ];
  };
}
