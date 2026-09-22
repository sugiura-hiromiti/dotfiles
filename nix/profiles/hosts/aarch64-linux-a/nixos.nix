{ lib, ... }:
{
  dotfiles.nixos.boot.performanceTuning.enable = lib.mkDefault true;
}
