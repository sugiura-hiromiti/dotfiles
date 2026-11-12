{
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  dotfiles = {
    features.sessionGui = {
      enable = lib.mkDefault true;
      session = lib.mkDefault "niri";
    };
    # SKK is used on both hosts, including alongside Hazkey on the X12.
    programs.libskk.enable = lib.mkDefault true;
  };

  # Satellite provides its own Xwayland; it does not require the independent
  # NixOS programs.xwayland switch.
  home.packages = [ pkgs.xwayland-satellite ];
}
