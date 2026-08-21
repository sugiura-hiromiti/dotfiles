{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.terminal;
in
{
  options =
    let
      terminalProviderModule = lib.types.submodule {
        options = {
          program = lib.mkOption { type = lib.types.str; };
          package = lib.mkOption { type = lib.types.package; };
          command = lib.mkOption { type = lib.types.str; };
          appId = lib.mkOption { type = lib.types.nullOr lib.types.str; };
          startupAppId = lib.mkOption { type = lib.types.nullOr lib.types.str; };
          startupCommand = lib.mkOption { type = lib.types.nullOr lib.types.str; };
          keybindCommand = lib.mkOption { type = lib.types.nullOr lib.types.str; };
        };
      };
    in
    {
      dotfiles = {
        terminalProviders = lib.mkOption {
          type = lib.types.attrsOf (terminalProviderModule);
          default = { };
        };
        features = {
          terminal = {
            enable = lib.mkEnableOption "terminal tools";

            programs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                # "alacritty"
                "aria2"
                "bottom"
                "carapace"
                "cargo"
                "direnv"
                "emacs"
                "eza"
                "fd"
                "fish"
                "fzf"
                "gh"
                # "ghostty"
                "git"
                "jujutsu"
                # "kitty"
                "lazygit"
                "nh"
                "nushell"
                "nvim"
                "ripgrep"
                "ssh"
                "starship"
                "translate-shell"
                # "wezterm"
                "yazi"
                "zoxide"
              ];
              description = "Repository program modules enabled with the terminal tools feature.";
            };
            provider = lib.mkOption {
              type = lib.types.str;
              description = "terminal provider to use";
            };
            selected = lib.mkOption {
              type = terminalProviderModule;
              default = { };
              readOnly = true;
            };
          };
        };
      };
    };

  config =
    let
      providers = config.dotfiles.terminalProviders;
      selected = providers.${cfg.provider};
    in
    lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = builtins.hasAttr cfg.provider providers;
          message = "unknown terminal provider: ${cfg.provider}";
        }
      ];
      dotfiles.programs =
        lib.genAttrs cfg.programs (_: {
          enable = lib.mkDefault true;
        })
        // lib.setAttrByPath [ selected.program "enable" ] true;

      home.packages = [ selected.package ];
    };
}
