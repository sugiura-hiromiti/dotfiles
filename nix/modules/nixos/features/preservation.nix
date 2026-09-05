{ lib, config, ... }:
let
  cfg = config.dotfiles.features.preservation;
in
{
  options = {
    dotfiles = {
      features = {
        preservation = {
          enable = lib.mkEnableOption "declarative persistent state";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    preservation = {
      enable = true;
      preserveAt = {
        "/persist" = {
          directories = [
            {
              directory = "/var/lib/nixos";
              inInitrd = true;
            }
          ]
          ++ lib.optionals config.services.tailscale.enable [ "/var/lib/tailscale" ]
          ++ lib.optionals config.hardware.bluetooth.enable [ "/var/lib/bluetooth" ]
          ++ lib.optionals config.services.power-profiles-daemon.enable [ "/var/lib/power-profiles-daemon" ];
          files = [
            {
              file = "/etc/machine-id";
              inInitrd = true;
            }
          ]
          ++ lib.optionals config.services.openssh.enable (
            map (key: {
              file = key.path;
              configureParent = true;
            }) config.services.openssh.hostKeys
          );
        };
      };
    };
  };
}
