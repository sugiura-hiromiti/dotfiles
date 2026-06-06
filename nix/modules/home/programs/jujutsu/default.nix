{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.jujutsu;
in
{
  options.dotfiles.programs.jujutsu.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure Jujutsu.";
  };

  config = lib.mkIf cfg.enable {
    programs.jujutsu = {
      enable = true;
      settings = {
        ui.editor = "emacsclient";
        user = {
          name = "sugiura-hiromiti";
          email = "pishadon57@gmail.com";
        };
      };
    };
  };
}
