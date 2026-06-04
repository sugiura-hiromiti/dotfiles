{
  hasGui ? false,
  lib,
  ...
}:
{
  dotfiles.features.noctaliaShell = {
    enable = lib.mkDefault hasGui;
    calendar.enable = lib.mkDefault true;
    clipboard.enable = lib.mkDefault true;
    ddc.enable = lib.mkDefault true;
    screenToolkit.enable = lib.mkDefault true;
    visualizer.enable = lib.mkDefault true;
    wallpaper.enable = lib.mkDefault true;
  };
}
