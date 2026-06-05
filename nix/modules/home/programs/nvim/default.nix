{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.nvim;
in
{
  options.dotfiles.programs.nvim.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the repository-managed Neovim configuration.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile = {
      "nvim/init.lua".source = ./config/init.lua;
      "nvim/lua" = {
        source = ./config/lua;
        recursive = true;
      };
      "nvim/after" = {
        source = ./config/after;
        recursive = true;
      };
    };
  };
}
