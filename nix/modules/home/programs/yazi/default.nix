{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.yazi;
in
{
  options.dotfiles.programs.yazi.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to enable Yazi.";
  };

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      enableNushellIntegration = true;
      plugins = with pkgs.yaziPlugins; {
        inherit git;
        inherit chmod;
        inherit yatline;
      };
      settings = builtins.fromTOML (builtins.readFile ./config/yazi.toml);
      keymap = builtins.fromTOML (builtins.readFile ./config/keymap.toml);
      initLua = ./config/init.lua;
    };
  };
}
