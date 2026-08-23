{
  hasGui ? false,
  lib,
  pkgs,
  ...
}:
{
  dotfiles.features.desktopIntegration = {
    enable = lib.mkDefault (hasGui && pkgs.stdenv.hostPlatform.isLinux);
  };
}
