{
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  dotfiles.features.sessionGui.enable = lib.mkDefault true;
}
