{ nix-hazkey }:
{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.hazkey;
in
{
  imports = [ nix-hazkey.nixosModules.hazkey ];
  options = {
    dotfiles = {
      programs = {
        hazkey = {
          enable = lib.mkEnableOption "Hazkey input method";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    services = {
      hazkey = {
        enable = true;
      };
    };
    i18n = {
      inputMethod = {
        fcitx5 = {
          settings = {
            inputMethod = {
              "Groups/0" = {
                DefaultIM = "hazkey";
              };
              "Groups/0/Items/1" = {
                Name = "hazkey";
              };
              "Groups/0/Items/2" = {
                Name = "skk";
              };
            };
          };
        };
      };
    };
  };
}
