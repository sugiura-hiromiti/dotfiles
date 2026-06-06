{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.zoxide;
in
{
  options.dotfiles.programs.zoxide.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to enable zoxide.";
  };

  config = lib.mkIf cfg.enable {
    programs.zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };
  };
}
