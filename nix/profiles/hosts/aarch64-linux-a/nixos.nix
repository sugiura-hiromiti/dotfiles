{ lib, ... }:
{
  imports = [ ./hardware-configuration.nix ];
  dotfiles.nixos.boot.performanceTuning.enable = lib.mkDefault true;
}
