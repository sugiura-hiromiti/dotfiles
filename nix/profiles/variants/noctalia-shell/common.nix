{
  hasGui ? false,
  lib,
  ...
}:
{
  dotfiles.features.noctaliaShell = {
    enable = lib.mkDefault hasGui;
    ddc.enable = lib.mkDefault true;
  };
}
