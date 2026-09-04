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
          ];
          files = [

          ];
        };
      };
    };
  };
}
