{ config, lib, ... }:
let
  cfg = config.dotfiles.features.autoRotation;
in
{
  options = {
    dotfiles = {
      features = {
        autoRotation = {
          enable = lib.mkEnableOption "automatic screen rotation";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    services = {
      iio-niri = {
        enable = true;
      };
    };
  };
}
