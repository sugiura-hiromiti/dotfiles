{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # check support of aarch64 linux
    surge-xt
    vital
    bristol
    nur.repos.aster-void.fcitx5-hazkey
  ];
}
