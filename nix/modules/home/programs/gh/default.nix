{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.gh;
in
{
  options.dotfiles.programs.gh.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to enable GitHub CLI.";
  };

  config = lib.mkIf cfg.enable {
    programs.gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
        prompt = "enabled";
        color_labels = "enabled";
      };
    };
  };
}
