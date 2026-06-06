{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.cargo;
in
{
  options.dotfiles.programs.cargo.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to configure Cargo.";
  };

  config = lib.mkIf cfg.enable {
    programs.cargo = {
      enable = true;
      package = null;
      settings.net.git-fetch-with-cli = true;
    };
  };
}
