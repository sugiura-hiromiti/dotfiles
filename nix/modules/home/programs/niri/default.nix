{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.niri;
  paths = config.dotfiles.paths;
  terminalCfg = cfg.terminal;
  kdlString = builtins.toJSON;
  regexFor = value: "^${lib.escapeRegex value}$";
  shellSpawnArgs = command: ''"sh" "-lc" ${kdlString command}'';
  terminalStartup = lib.optionalString (
    terminalCfg.enable && terminalCfg.startup.enable && terminalCfg.startupCommand != null
  ) "spawn-at-startup ${shellSpawnArgs terminalCfg.startupCommand}";
  terminalStartupWindowMatch = lib.optionalString (
    terminalCfg.enable && terminalCfg.startupWindowRule.enable && terminalCfg.startupAppId != null
  ) "    match at-startup=true app-id=${kdlString (regexFor terminalCfg.startupAppId)}";
  terminalWindowRule =
    lib.optionalString
      (terminalCfg.enable && terminalCfg.windowRule.enable && terminalCfg.appId != null)
      (
        lib.concatStringsSep "\n" [
          "window-rule {"
          "    match app-id=${kdlString (regexFor terminalCfg.appId)}"
          "    open-floating true"
          "    default-column-width { fixed 2000; }"
          "    default-window-height { proportion 0.6; }"
          "}"
        ]
      );
  terminalKeybind =
    lib.optionalString
      (terminalCfg.enable && terminalCfg.keybind.enable && terminalCfg.keybindCommand != null)
      "    Mod+T hotkey-overlay-title=\"Open a Terminal\" { spawn ${shellSpawnArgs terminalCfg.keybindCommand}; }";
  niriConfig =
    pkgs.runCommandLocal "niri-config"
      {
        inherit
          terminalKeybind
          terminalStartup
          terminalStartupWindowMatch
          terminalWindowRule
          ;
      }
      ''
        mkdir -p "$out"
        cp -R "${./config}/." "$out/"
        chmod -R u+w "$out"
        substituteInPlace "$out/config.kdl" \
          --replace-fail "~/Downloads/media/screenshots" "${paths.screenshotDirectory}" \
          --replace-fail "@terminalStartup@" "$terminalStartup" \
          --replace-fail "@terminalStartupWindowMatch@" "$terminalStartupWindowMatch" \
          --replace-fail "@terminalWindowRule@" "$terminalWindowRule" \
          --replace-fail "@terminalKeybind@" "$terminalKeybind"
      '';
in
{
  options.dotfiles.programs.niri = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to install the repository-managed niri configuration.";
    };

    terminal = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to generate niri integration for the configured terminal provider.";
      };

      appId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = config.dotfiles.features.terminal.appId;
        defaultText = lib.literalExpression "config.dotfiles.features.terminal.appId";
        description = "Application ID matched by niri terminal window rules.";
      };

      startupAppId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = config.dotfiles.features.terminal.startupAppId;
        defaultText = lib.literalExpression "config.dotfiles.features.terminal.startupAppId";
        description = "Application ID matched by niri startup terminal window rules.";
      };

      startupCommand = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = config.dotfiles.features.terminal.startupCommand;
        defaultText = lib.literalExpression "config.dotfiles.features.terminal.startupCommand";
        description = "Terminal command niri runs at startup.";
      };

      keybindCommand = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = config.dotfiles.features.terminal.keybindCommand;
        defaultText = lib.literalExpression "config.dotfiles.features.terminal.keybindCommand";
        description = "Terminal command niri runs from its terminal key binding.";
      };

      startup.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether niri opens the configured terminal at startup.";
      };

      startupWindowRule.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether niri matches startup terminal windows.";
      };

      windowRule.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether niri applies terminal-specific window rules.";
      };

      keybind.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether niri binds a key to open the configured terminal.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          !terminalCfg.enable || !terminalCfg.startup.enable || terminalCfg.startupCommand != null;
        message = "dotfiles.programs.niri.terminal.startup.enable requires dotfiles.programs.niri.terminal.startupCommand.";
      }
      {
        assertion =
          !terminalCfg.enable || !terminalCfg.startupWindowRule.enable || terminalCfg.startupAppId != null;
        message = "dotfiles.programs.niri.terminal.startupWindowRule.enable requires dotfiles.programs.niri.terminal.startupAppId.";
      }
      {
        assertion = !terminalCfg.enable || !terminalCfg.windowRule.enable || terminalCfg.appId != null;
        message = "dotfiles.programs.niri.terminal.windowRule.enable requires dotfiles.programs.niri.terminal.appId.";
      }
      {
        assertion =
          !terminalCfg.enable || !terminalCfg.keybind.enable || terminalCfg.keybindCommand != null;
        message = "dotfiles.programs.niri.terminal.keybind.enable requires dotfiles.programs.niri.terminal.keybindCommand.";
      }
    ];

    xdg.configFile."niri" = {
      source = niriConfig;
      recursive = true;
    };
  };
}
