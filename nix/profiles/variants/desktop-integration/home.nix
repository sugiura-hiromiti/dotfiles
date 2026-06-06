{
  hasGui ? false,
  lib,
  system,
  ...
}:
{
  dotfiles.features.desktopIntegration = {
    enable = lib.mkDefault (hasGui && lib.hasSuffix "-linux" system);
    termfilechooser.enable = lib.mkDefault true;
    portal.enable = lib.mkDefault true;
    mimeApps.enable = lib.mkDefault true;
  };
}
