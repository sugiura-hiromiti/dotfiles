{
  lib,
  config,
  ...
}:
let
  cfg = config.dotfiles.features.desktopIntegration;
in
{
  options = {
    dotfiles = {
      features = {
        desktopIntegration = {
          orgProtocol = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = config.programs.emacs.enable;
              defaultText = lib.literalExpression "config.programs.emacs.enable";
              description = "Whether to register org-protocol URL handling.";
            };
            emacsPackage = lib.mkOption {
              type = lib.types.package;
              default = config.programs.emacs.finalPackage;
              defaultText = lib.literalExpression "config.programs.emacs.finalPackage";
              description = "Emacs package that provides emacsclient for org-protocol.";
            };
          };
        };
      };
    };
  };
  config = lib.mkIf (cfg.enable && cfg.orgProtocol.enable) {
    assertions = [
      {
        # TODO: このへんは自動で有効無効にして欲しい
        assertion = !cfg.orgProtocol.enable || config.programs.emacs.enable;
        message = "dotfiles.features.desktopIntegration.orgProtocol requires programs.emacs.enable.";
      }
    ];
    xdg = {
      desktopEntries.org-protocol = {
        name = "org-protocol";
        comment = "handle org-protocol:// urls with emacsclient";
        exec = "${cfg.orgProtocol.emacsPackage}/bin/emacsclient -n -- %u";
        terminal = false;
        type = "Application";
        categories = [ "Utility" ];
        mimeType = [ "x-scheme-handler/org-protocol" ];
      };
    };
  };
}
