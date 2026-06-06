{ lib, ... }:
{
  dotfiles.features.media.enable = lib.mkDefault true;
  dotfiles.programs.firefox.enable = lib.mkDefault true;
}
