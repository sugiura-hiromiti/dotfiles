{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.lazygit;
in
{
  options.dotfiles.programs.lazygit.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to enable lazygit.";
  };

  config = lib.mkIf cfg.enable {
    programs.lazygit = {
      enable = true;
      enableNushellIntegration = true;
      shellWrapperName = "lg";
      settings = { };
    };
  };
}
