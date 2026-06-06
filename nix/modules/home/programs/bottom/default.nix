{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.bottom;
in
{
  options.dotfiles.programs.bottom.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to enable bottom.";
  };

  config = lib.mkIf cfg.enable {
    programs.bottom = {
      enable = true;
      settings.flags.battery = true;
    };
  };
}
