{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.dotfiles.features.desktopIntegration;
  terminal = config.dotfiles.features.terminal;
  provider = terminal.selected;
  termCommand = provider.mkCommand {
    wait = true;
  };
  termfilechooserRuntimePath = lib.makeBinPath [
    cfg.termfilechooser.fileManager.package
    provider.package
    pkgs.bash
    pkgs.coreutils
    pkgs.gnused
  ];
  termfilechooserWrapper = pkgs.writeShellScript "termfilechooser-yazi-wrapper" ''
    export TERMCMD=${lib.escapeShellArg termCommand}
    export PATH=${lib.escapeShellArg termfilechooserRuntimePath}
    exec ${cfg.termfilechooser.package}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh "$@"
  '';
in
{
  options = {
    dotfiles = {
      features = {
        desktopIntegration = {
          termfilechooser = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = terminal.enable;
              description = "Whether to configure xdg-desktop-portal-termfilechooser.";
            };
            package = lib.mkOption {
              type = lib.types.package;
              default = pkgs.xdg-desktop-portal-termfilechooser;
              defaultText = lib.literalExpression "pkgs.xdg-desktop-portal-termfilechooser";
              description = "xdg-desktop-portal-termfilechooser package.";
            };
            fileManager.package = lib.mkOption {
              type = lib.types.package;
              default = config.programs.yazi.package;
              defaultText = lib.literalExpression "config.programs.yazi.package";
              description = "File manager package used by the terminal file chooser wrapper.";
            };
          };
        };
      };
    };
  };
  config = lib.mkIf (cfg.enable && cfg.termfilechooser.enable) {
    xdg = {
      configFile."xdg-desktop-portal-termfilechooser/config".text = ''
        [filechooser]
        cmd=${termfilechooserWrapper}
        default_dir=$HOME
        open_mode=suggested
        save_mode=suggested
      '';
    };
  };
}
