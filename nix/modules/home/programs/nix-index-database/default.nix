{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.nix-index-database;
in
{
  options = {
    dotfiles = {
      programs = {
        nix-index-database = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "whether to install nix-index-database and enables comma";
          };
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    programs = {
      nix-index-database = {
        comma = {
          enable = true;
        };
      };
    };
  };
}
