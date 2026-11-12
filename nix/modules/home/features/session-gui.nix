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
    enable = lib.mkEnableOption "graphical session user configuration";

    session = lib.mkOption {
      type = lib.types.enum [ "niri" ];
      default = "niri";
      description = "Graphical session whose user configuration is provided.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "dotfiles.features.sessionGui is Linux-only.";
      }
      {
        assertion = config.dotfiles.programs.niri.enable;
        message = "dotfiles.features.sessionGui.session = niri requires dotfiles.programs.niri.enable.";
      }
    ];

    dotfiles.programs.niri.enable = lib.mkDefault true;
  };
}
