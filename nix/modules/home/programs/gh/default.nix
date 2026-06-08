{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.gh;
in
{
  options.dotfiles.programs.gh = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable GitHub CLI.";
    };

    gitCredentialHelper = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to configure Git to use GitHub CLI as a credential helper.";
      };

      hosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "https://github.com"
          "https://gist.github.com"
        ];
        description = "GitHub hosts to configure for the GitHub CLI credential helper.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.gh = {
      enable = true;
      inherit (cfg) gitCredentialHelper;
      settings = {
        git_protocol = "ssh";
        prompt = "enabled";
        color_labels = "enabled";
      };
    };
  };
}
