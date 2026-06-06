{
  lib,
  system,
  ...
}:
lib.mkIf (lib.hasSuffix "-linux" system) {
  dotfiles.features.sessionGui.enable = lib.mkDefault true;
}
