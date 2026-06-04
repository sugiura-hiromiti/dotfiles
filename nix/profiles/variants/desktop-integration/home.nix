{ lib, ... }:
{
  dotfiles.features.desktopIntegration = {
    orgProtocol.enable = lib.mkDefault true;
    mimeApps.enable = lib.mkDefault true;
  };
}
