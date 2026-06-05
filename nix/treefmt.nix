{
  lib,
  pkgs,
  ...
}:
let
  formatters = import ./formatters { inherit lib pkgs; };
in
{
  projectRootFile = ".git/config";

  programs = {
    dprint = {
      enable = true;
      includes = [
        "*.json"
        "*.jsonc"
        "*.md"
        "*.yaml"
        "*.yml"
      ];
      settings = formatters.dprint.settings;
    };

    fish_indent.enable = true;

    nixfmt = {
      enable = true;
      package = pkgs.nixfmt;
    };

    stylua = {
      enable = true;
      settings = formatters.stylua.settings;
    };

    # dprint rewrites TOML schema directives such as #:schema; taplo preserves them.
    taplo.enable = true;
  };
}
