{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.emacs;
  paths = config.dotfiles.paths;
  emacsLispFiles = lib.attrNames (
    lib.filterAttrs (
      name: type:
      !builtins.elem name [
        "init-paths.el"
      ]
      && type == "regular"
      && lib.hasSuffix ".el" name
    ) (builtins.readDir ./config/lisp)
  );
  emacsLispConfigFiles = lib.listToAttrs (
    map (name: {
      name = "emacs/lisp/${name}";
      value.source = ./config/lisp + "/${name}";
    }) emacsLispFiles
  );
  emacsLibFiles = lib.attrNames (
    lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".el" name) (
      builtins.readDir ./config/lib
    )
  );
  emacsLispLibFiles = lib.listToAttrs (
    map (name: {
      name = "emacs/lib/${name}";
      value = {
        source = ./config/lib + "/${name}";
      };
    }) emacsLibFiles
  );
  emacsPathsConfig = ''
    ;;; -*- lexical-binding: t; -*-
    ;; Generated from dotfiles.paths by Home Manager.

    (defconst my/dotfiles-downloads ${builtins.toJSON paths.downloads})
    (defconst my/dotfiles-media-directory ${builtins.toJSON paths.mediaDirectory})
    (defconst my/dotfiles-workspace-root ${builtins.toJSON paths.workspaceRoot})
    (defconst my/dotfiles-org-directory ${builtins.toJSON paths.orgDirectory})
    (defconst my/dotfiles-wallpaper-directory ${builtins.toJSON paths.wallpaperDirectory})
    (defconst my/dotfiles-screenshot-directory ${builtins.toJSON paths.screenshotDirectory})

    (provide 'init-paths)
  '';
  emacsPackage = pkgs.emacs-pgtk;
  configuredEmacsPackage = config.programs.emacs.package;
  emacsEditor = toString (
    lib.getBin (
      pkgs.writeShellScript "emacs-editor" ''
        exec ${configuredEmacsPackage}/bin/emacsclient "''${@:---create-frame}"
      ''
    )
  );
in
{
  imports = [ ./darwin-app.nix ];
  options = {
    dotfiles = {
      programs = {
        emacs = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether to install and configure Emacs.";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.sessionVariables = {
      EDITOR = lib.mkDefault emacsEditor;
      VISUAL = lib.mkDefault emacsEditor;
    };

    programs.emacs = {
      enable = lib.mkDefault true;
      package = lib.mkDefault emacsPackage;
    };

    services.emacs = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) {
      enable = lib.mkDefault true;
      startWithUserSession = lib.mkDefault false;
      socketActivation.enable = lib.mkDefault true;
      client.enable = lib.mkDefault true;
    };

    xdg.configFile = {
      "emacs/init.el".source = ./config/init.el;
      "emacs/early-init.el".source = ./config/early-init.el;
      "emacs/lisp/init-paths.el".text = emacsPathsConfig;
    }
    // emacsLispConfigFiles
    // emacsLispLibFiles;
  };
}
