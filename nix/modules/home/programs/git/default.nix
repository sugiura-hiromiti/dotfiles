{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.git;
in
{
  options.dotfiles.programs.git.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure Git.";
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      settings = {
        core.editor = "emacsclient";
        init.defaultBranch = "main";
        pull = {
          rebase = false;
          ff = "only";
        };
        user = {
          name = "sugiura-hiromiti";
          email = "pishadon57@gmail.com";
        };
      };
      includes = [ { path = "~/.github_auth"; } ];
      ignores = [
        ".direnv/"
        ".serena/"
        ".DS_Store"
        "dist-newstyle/"
        ".agent-shell/"
      ];
    };
  };
}
