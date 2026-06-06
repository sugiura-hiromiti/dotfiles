{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.darwin.xdgEnv;
in
{
  options.dotfiles.darwin.xdgEnv.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to export XDG paths to GUI apps through launchd.";
  };

  config = lib.mkIf cfg.enable {
    launchd.user.agents."xdg-env".serviceConfig = {
      RunAtLoad = true;
      KeepAlive = false;
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          /bin/launchctl setenv XDG_CONFIG_HOME "$HOME/.config"
          /bin/launchctl setenv XDG_DATA_HOME "$HOME/.local/share"
          /bin/launchctl setenv XDG_STATE_HOME "$HOME/.local/state"
          /bin/launchctl setenv XDG_CACHE_HOME "$HOME/.cache"
        ''
      ];
    };
  };
}
