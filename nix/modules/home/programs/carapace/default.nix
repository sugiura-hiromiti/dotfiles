{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.carapace;
in
{
  options.dotfiles.programs.carapace.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to enable Carapace.";
  };

  config = lib.mkIf cfg.enable {
    programs.carapace = {
      enable = true;
      enableNushellIntegration = true;
    };
  };
}
