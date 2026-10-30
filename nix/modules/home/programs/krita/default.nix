{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.krita;
in
{
  options = {
    dotfiles = {
      programs = {
        krita = {
          enable = lib.mkEnableOption "krita painting application";
        };
      };
    };
  };
  config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isLinux) {
    home = {
      packages = [ pkgs.krita ];
    };
  };
}
