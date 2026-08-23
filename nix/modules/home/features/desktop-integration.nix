{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.desktopIntegration;
in
{
  imports = [
    ./desktop-integration/termfilechooser.nix
    ./desktop-integration/portal.nix
    ./desktop-integration/org-protocol.nix
    ./desktop-integration/mime-apps.nix
  ];
  options = {
    dotfiles = {
      features = {
        desktopIntegration = {
          enable = lib.mkEnableOption "desktop integration";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "dotfiles.features.desktopIntegration is Linux-only.";
      }
      {
        # TODO: このへんは自動で有効無効にして欲しい
        assertion = !cfg.orgProtocol.enable || config.programs.emacs.enable;
        message = "dotfiles.features.desktopIntegration.orgProtocol requires programs.emacs.enable.";
      }
    ];
  };
}
