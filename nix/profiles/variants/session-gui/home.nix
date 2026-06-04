{
  pkgs,
  lib,
  system,
  ...
}:
lib.mkIf (lib.hasSuffix "-linux" system) {
  home.packages = with pkgs; [
    xwayland-satellite
  ];
}
