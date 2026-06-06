{
  account ? { },
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.git;
  gitAccount = account.git or { };
  userSettings =
    lib.optionalAttrs (gitAccount ? name) {
      inherit (gitAccount) name;
    }
    // lib.optionalAttrs (gitAccount ? email) {
      inherit (gitAccount) email;
    };
in
{
  options.dotfiles.programs.git.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
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
      }
      // lib.optionalAttrs (userSettings != { }) { user = userSettings; };
      includes = gitAccount.includes or [ ];
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
