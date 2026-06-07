{
  lib,
  pkgs,
  ...
}:
let
  hazkeyPackages = lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    pkgs.nur.repos.aster-void.fcitx5-hazkey
  ];
in
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  dotfiles.features.sessionGui.enable = lib.mkDefault true;

  dotfiles.programs = {
    fcitx5 = {
      enable = lib.mkDefault true;
      packages = lib.mkDefault hazkeyPackages;
    };
    ironbar.enable = lib.mkDefault true;
    libskk.enable = lib.mkDefault true;
    niri.enable = lib.mkDefault true;
    omniwm.enable = lib.mkDefault true;
  };
}
