{
  account ? { },
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.jujutsu;
  jujutsuAccount = account.jujutsu or account.git or { };
  userSettings =
    lib.optionalAttrs (jujutsuAccount ? name) {
      inherit (jujutsuAccount) name;
    }
    // lib.optionalAttrs (jujutsuAccount ? email) {
      inherit (jujutsuAccount) email;
    };
in
{
  options.dotfiles.programs.jujutsu.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to configure Jujutsu.";
  };

  config = lib.mkIf cfg.enable {
    programs.jujutsu = {
      enable = true;
      settings = {
        ui.editor = "emacsclient";
      }
      // lib.optionalAttrs (userSettings != { }) { user = userSettings; };
    };
  };
}
