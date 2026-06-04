{ pkgs, ... }:
let
  dprintSettings = builtins.fromJSON (builtins.readFile ./formatters/dprint-settings.json);
  styluaSettings = builtins.fromTOML (builtins.readFile ./formatters/stylua.toml);
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
      settings = dprintSettings // {
        plugins = pkgs.dprint-plugins.getPluginList (
          plugins: with plugins; [
            dprint-plugin-json
            dprint-plugin-markdown
            dprint-plugin-typescript
            g-plane-pretty_yaml
          ]
        );
      };
    };

    fish_indent.enable = true;

    nixfmt = {
      enable = true;
      package = pkgs.nixfmt;
    };

    stylua = {
      enable = true;
      settings = styluaSettings;
    };

    # dprint rewrites TOML schema directives such as #:schema; taplo preserves them.
    taplo.enable = true;
  };
}
