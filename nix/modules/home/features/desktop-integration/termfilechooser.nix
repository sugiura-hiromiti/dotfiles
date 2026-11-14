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
    withCommand = true;
  };
  termfilechooserRuntimePath = lib.makeBinPath [
    cfg.termfilechooser.fileManager.package
    provider.package
    pkgs.bash
    pkgs.coreutils
  ];
  termfilechooserWrapper = pkgs.writeShellScript "termfilechooser-yazi-wrapper" ''
    export PATH=${lib.escapeShellArg termfilechooserRuntimePath}
    # The daemon appends its own terminal argv after these six inputs. Replace
    # that tail with the selected provider's waiting command; setting TERMCMD
    # here would be too late for the daemon's expansion.
    exec ${cfg.termfilechooser.package}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh \
      "$1" "$2" "$3" "$4" "$5" "$6" ${termCommand}
  '';
in
{
  options = {
    dotfiles = {
      features = {
        desktopIntegration = {
          termfilechooser = {
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
              description = ''
                Yazi-compatible package providing bin/yazi with --chooser-file
                and --cwd-file support. programs.yazi.enable is not required.
              '';
            };
          };
        };
      };
    };
  };
  config =
    lib.mkIf (cfg.enable && cfg.portal.enable && cfg.portal.fileChooser.backend == "termfilechooser")
      {
        assertions = [
          {
            assertion = terminal.enable;
            message = "dotfiles.features.desktopIntegration termfilechooser requires dotfiles.features.terminal.enable and a configured terminal provider.";
          }
        ];
        xdg = lib.mkIf terminal.enable {
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
