{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.starship;
in
{
  options.dotfiles.programs.starship.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to enable Starship.";
  };

  config = lib.mkIf cfg.enable {
    programs.starship = {
      enable = true;
      settings.battery.display = [
        { threshold = 20; }
      ];
      enableNushellIntegration = true;
    };
  };
}
