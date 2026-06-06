{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.fd;
in
{
  options.dotfiles.programs.fd.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to enable fd.";
  };

  config = lib.mkIf cfg.enable {
    programs.fd.enable = true;
  };
}
