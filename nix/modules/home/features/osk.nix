{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.osk;
in
{
  options = {
    dotfiles = {
      features = {
        osk = {
          enable = lib.mkEnableOption "on-screen keyboard";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    dotfiles = {
      programs = {
        wvkbd = {
          enable = true;
        };
      };
    };
    home = {
      packages = [
        (pkgs.writeShellScriptBin "osk-toggle" ''
          exec ${config.dotfiles.programs.wvkbd.toggleCommand}
        '')
      ];
    };
  };
}
