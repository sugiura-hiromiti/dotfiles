{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.nixos.hardware;
in
{
  options.dotfiles.nixos.hardware.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure baseline hardware and power services.";
  };

  config = lib.mkIf cfg.enable {
    hardware.bluetooth.enable = lib.mkDefault true;

    services = {
      upower.enable = lib.mkDefault true;
      power-profiles-daemon.enable = lib.mkDefault true;
      xserver.enable = lib.mkDefault false;
    };
  };
}
