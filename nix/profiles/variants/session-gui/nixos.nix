{ lib, ... }:
{
  dotfiles.features.sessionGui.enable = lib.mkDefault true;
}
