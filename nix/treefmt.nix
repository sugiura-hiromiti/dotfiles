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

  # Generated completions are kept as-is; formatter output is not stable.
  settings = lib.recursiveUpdate formatters.settings {
    global = {
      excludes = [
        # actions.nix is the sole owner
        ".github/workflows/**"
      ];
    };
    formatter.tombi = {
      command = lib.getExe pkgs.tombi;
      options = [ "format" ];
      includes = [ "*.toml" ];
    };
  };

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

    nixfmt = {
      enable = true;
      package = pkgs.nixfmt;
    };

    stylua = {
      enable = true;
      settings = formatters.stylua.settings;
    };
  };
}
