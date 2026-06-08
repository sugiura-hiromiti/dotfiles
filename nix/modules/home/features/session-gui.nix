{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.sessionGui;
in
{
  options.dotfiles.features.sessionGui = {
    enable = lib.mkEnableOption "graphical session user packages";

    programs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "fcitx5"
        "ironbar"
        "libskk"
        "niri"
        "omniwm"
      ];
      description = "Repository program modules enabled with the graphical session feature.";
    };

    fcitx5.packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = lib.optionals (pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isx86_64) [
        pkgs.nur.repos.aster-void.fcitx5-hazkey
      ];
      description = "Additional Fcitx 5 packages installed for graphical sessions.";
    };

    xwaylandSatellite.package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.xwayland-satellite;
      defaultText = lib.literalExpression "pkgs.xwayland-satellite";
      description = "xwayland-satellite package to install for Wayland sessions.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = pkgs.stdenv.hostPlatform.isLinux;
            message = "dotfiles.features.sessionGui is Linux-only.";
          }
        ];

        dotfiles.programs = lib.genAttrs cfg.programs (_: {
          enable = lib.mkDefault true;
        });

        home.packages = [
          cfg.xwaylandSatellite.package
        ];
      }

      (lib.mkIf (lib.elem "fcitx5" cfg.programs) {
        dotfiles.programs.fcitx5.packages = lib.mkDefault cfg.fcitx5.packages;
      })
    ]
  );
}
