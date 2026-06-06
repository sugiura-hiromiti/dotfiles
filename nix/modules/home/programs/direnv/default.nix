{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.direnv;
in
{
  options.dotfiles.programs.direnv.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to enable direnv.";
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableNushellIntegration = true;
    };
  };
}
