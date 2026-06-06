{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.ripgrep;
in
{
  options.dotfiles.programs.ripgrep.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to enable ripgrep.";
  };

  config = lib.mkIf cfg.enable {
    programs.ripgrep = {
      enable = true;
      arguments = [
        "--smart-case"
        "-."
        "-L"
      ];
    };
  };
}
