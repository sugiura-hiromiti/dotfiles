{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.emacs;
  emacsPackage = (pkgs.emacsPackagesFor pkgs.emacs-pgtk).emacsWithPackages (epkgs: [
    epkgs.tree-sitter-langs
    (epkgs.treesit-grammars.with-grammars (grammars: [
      grammars.tree-sitter-rust
      grammars.tree-sitter-typescript
      grammars.tree-sitter-haskell
      grammars.tree-sitter-toml
      grammars.tree-sitter-nu
      grammars.tree-sitter-csv
      grammars.tree-sitter-diff
      grammars.tree-sitter-gitcommit
      grammars.tree-sitter-gitignore
      grammars.tree-sitter-json
      grammars.tree-sitter-kdl
      grammars.tree-sitter-lua
      grammars.tree-sitter-markdown
      grammars.tree-sitter-markdown-inline
      grammars.tree-sitter-nix
      grammars.tree-sitter-sql
      grammars.tree-sitter-yaml
      grammars.tree-sitter-tsx
      grammars.tree-sitter-html
    ]))
  ]);
in
{
  options.dotfiles.programs.emacs.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install and configure Emacs.";
  };

  config = lib.mkIf cfg.enable {
    programs.emacs = {
      enable = lib.mkDefault true;
      package = lib.mkDefault emacsPackage;
    };

    services.emacs = {
      enable = lib.mkDefault true;
      startWithUserSession = lib.mkDefault "graphical";
      client.enable = lib.mkDefault true;
      defaultEditor = lib.mkDefault true;
    };

    xdg.configFile = {
      "emacs/init.el".source = ./config/init.el;
      "emacs/early-init.el".source = ./config/early-init.el;
      "emacs/lisp" = {
        source = ./config/lisp;
        recursive = true;
      };
    };
  };
}
