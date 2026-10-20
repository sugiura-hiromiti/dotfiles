{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.reaper;
in
{
  options.dotfiles.programs.reaper.enable =
    lib.mkEnableOption "repository-managed REAPER configuration";

  config = lib.mkIf cfg.enable {
    programs.reaper = {
      enable = true;
      theme = { };
    };
  };
}
