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
  options.dotfiles.features.terminal = {
    enable = lib.mkEnableOption "terminal tools";

    programs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "alacritty"
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
        "ghostty"
        "git"
        "jujutsu"
        "kitty"
        "lazygit"
        "nh"
        "nushell"
        "nvim"
        "ripgrep"
        "ssh"
        "starship"
        "translate-shell"
        "wezterm"
        "yazi"
        "zoxide"
      ];
      description = "Repository program modules enabled with the terminal tools feature.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.wezterm;
      defaultText = lib.literalExpression "pkgs.wezterm";
      description = "Terminal package used by desktop features.";
    };

    command = lib.mkOption {
      type = lib.types.str;
      default = "${lib.getExe cfg.package} start";
      defaultText = lib.literalExpression ''"${lib.getExe config.dotfiles.features.terminal.package} start"'';
      description = "Terminal command used by features that need to launch a terminal.";
    };

    appId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Application ID used by desktop integrations to identify terminal windows.";
    };

    startupAppId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Application ID used by desktop integrations to identify startup terminal windows.";
    };

    startupCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Terminal command used by desktop integrations that open a terminal at startup.";
    };

    keybindCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = cfg.command;
      defaultText = lib.literalExpression "config.dotfiles.features.terminal.command";
      description = "Terminal command used by desktop integrations that open a terminal from a key binding.";
    };
  };

  config = lib.mkIf cfg.enable {
    dotfiles.programs = lib.genAttrs cfg.programs (_: {
      enable = lib.mkDefault true;
    });

    home.packages = [ cfg.package ];
  };
}
