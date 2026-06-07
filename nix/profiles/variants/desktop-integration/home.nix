{
  hasGui ? false,
  lib,
  pkgs,
  ...
}:
{
  dotfiles.features.desktopIntegration = {
    enable = lib.mkDefault (hasGui && pkgs.stdenv.hostPlatform.isLinux);
    termfilechooser.enable = lib.mkDefault true;
    portal.enable = lib.mkDefault true;
    mimeApps.enable = lib.mkDefault true;
  };
}
