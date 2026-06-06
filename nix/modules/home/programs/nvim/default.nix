{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.nvim;
in
{
  options.dotfiles.programs.nvim = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install the repository-managed Neovim configuration.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.neovim;
      defaultText = lib.literalExpression "pkgs.neovim";
      description = "The Neovim package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

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
