{
  config,
  lib,
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
          package = lib.mkOption { type = lib.types.package; };
          mkCommand = lib.mkOption {
            type = lib.types.functionTo lib.types.str;
          };
        };
      };
      launchOption = lib.types.submodule {
        options = {
          appId = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };
      };
    in
    {
      dotfiles = {
        terminalProviders = lib.mkOption {
          type = lib.types.attrsOf terminalProviderModule;
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
              readOnly = true;
            };
            role = {
              regular = lib.mkOption {
                type = launchOption;
                readOnly = true;
              };
              transient = lib.mkOption {
                type = launchOption;
                readOnly = true;
              };
            };
          };
        };
      };
    };

  config =
    let
      providers = config.dotfiles.terminalProviders;
      selected = providers.${cfg.provider} or null;
    in
    lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = selected != null;
          message = "unknown terminal provider: ${cfg.provider}";
        }
      ];
      dotfiles = {
        programs =
          lib.genAttrs cfg.programs (_: {
            enable = lib.mkDefault true;
          })
          // lib.setAttrByPath [ cfg.provider "enable" ] true;
        features = {
          terminal = {
            inherit selected;
            roel = {
              transient = {
                appId = "dotfiles.terminal.transient";
              };
            };
          };
        };
      };
      home = {
        packages = [ selected.package ];
      };
    };
}
