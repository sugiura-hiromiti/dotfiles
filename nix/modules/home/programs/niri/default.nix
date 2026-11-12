{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.niri;
  terminal = config.dotfiles.features.terminal;
  provider = terminal.selected;
  tiledCommand = provider.mkCommand { inherit (terminal.role.tiled) appId; };
  paths = config.dotfiles.paths;
  terminalCfg = cfg.terminal;
  noctalia = config.programs.noctalia;
  noctaliaCfg = cfg.noctalia;
  kdlString = builtins.toJSON;
  regexFor = value: "^${lib.escapeRegex value}$";
  shellSpawnArgs = command: ''"sh" "-lc" ${kdlString command}'';
  terminalStartup = lib.optionalString (
    terminalCfg.enable && terminalCfg.startup.enable
  ) "spawn-at-startup ${shellSpawnArgs tiledCommand}";
  floatingTerminalWindowRule =
    lib.optionalString
      (
        terminalCfg.enable && terminalCfg.floatingWindowRule.enable && terminal.role.floating.appId != null
      )
      (
        lib.concatStringsSep "\n" [
          "window-rule {"
          "    match app-id=${kdlString (regexFor terminal.role.floating.appId)}"
          "    open-floating true"
          "    default-column-width { proportion 0.8; }"
          "    default-window-height { proportion 0.6; }"
          "}"
        ]
      );
  terminalKeybind = lib.optionalString (
    terminalCfg.enable && terminalCfg.keybind.enable
  ) "    Mod+T hotkey-overlay-title=\"Open a Terminal\" { spawn ${shellSpawnArgs tiledCommand}; }";
  noctaliaStartup = lib.optionalString (
    noctaliaCfg.enable && noctalia.enable && noctaliaCfg.startup.enable && !noctalia.systemd.enable
  ) ''spawn-at-startup "noctalia"'';
  noctaliaKeybinds = lib.optionalString (noctaliaCfg.enable && noctalia.enable) ''
    Mod+Space repeat=false { spawn "noctalia" "msg" "panel-toggle" "launcher"; }
    Mod+C repeat=false { spawn "noctalia" "msg" "panel-toggle" "clipboard"; }
    Mod+Escape repeat=false { spawn "noctalia" "msg" "panel-toggle" "session"; }
    Mod+N { spawn "noctalia" "msg" "notification-clear-active"; }
    XF86AudioRaiseVolume allow-when-locked=true { spawn "noctalia" "msg" "volume-up"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn "noctalia" "msg" "volume-down"; }
    Shift+XF86AudioRaiseVolume allow-when-locked=true { spawn "noctalia" "msg" "mic-volume-up"; }
    Shift+XF86AudioLowerVolume allow-when-locked=true { spawn "noctalia" "msg" "mic-volume-down"; }
    XF86MonBrightnessUp   allow-when-locked=true { spawn "noctalia" "msg" "brightness-up"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn "noctalia" "msg" "brightness-down"; }
  '';
  niriConfig =
    pkgs.runCommandLocal "niri-config"
      {
        inherit
          absoluteInputConfig
          terminalKeybind
          terminalStartup
          floatingTerminalWindowRule
          noctaliaStartup
          noctaliaKeybinds
          ;
      }
      ''
        mkdir -p "$out"
        cp -R "${./config}/." "$out/"
        chmod -R u+w "$out"
        substituteInPlace "$out/config.kdl" \
          --replace-fail "~/Downloads/media/screenshots" "${paths.screenshotDirectory}" \
          --replace-fail "@terminalStartup@" "$terminalStartup" \
          --replace-fail "@floatingTerminalWindowRule@" "$floatingTerminalWindowRule" \
          --replace-fail "@terminalKeybind@" "$terminalKeybind" \
          --replace-fail "@noctaliaStartup@" "$noctaliaStartup" \
          --replace-fail "@noctaliaKeybinds@" "$noctaliaKeybinds" \
          --replace-fail "@absoluteInputConfig@" "$absoluteInputConfig"
      '';
  absoluteInputConfig = lib.optionalString (cfg.absoluteInputOutput != null) ''
    touch {
      map-to-output ${kdlString cfg.absoluteInputOutput}
    }
    tablet {
      map-to-output ${kdlString cfg.absoluteInputOutput}
    }
  '';
in
{
  options.dotfiles.programs.niri = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to install the repository-managed niri configuration.";
    };

    absoluteInputOutput = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Output for touchscreen and tablet input.";
    };

    noctalia = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = noctalia.enable;
        description = "Whether to generate Niri integration for the enabled Noctalia Shell.";
      };

      startup.enable = lib.mkOption {
        type = lib.types.bool;
        default = noctaliaCfg.enable && !noctalia.systemd.enable;
        description = "Whether Niri starts Noctalia when its upstream systemd service is disabled.";
      };
    };

    # TODO: このへん色々なくせそう
    terminal = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = terminal.enable;
        description = "Whether to generate niri integration for the configured terminal provider.";
      };

      startup.enable = lib.mkOption {
        type = lib.types.bool;
        default = terminalCfg.enable;
        description = "Whether niri opens the configured terminal at startup.";
      };

      floatingWindowRule.enable = lib.mkOption {
        type = lib.types.bool;
        default = terminalCfg.enable;
        description = "Whether niri applies terminal-specific window rules.";
      };

      keybind.enable = lib.mkOption {
        type = lib.types.bool;
        default = terminalCfg.enable;
        description = "Whether niri binds a key to open the configured terminal.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.home.file."${config.xdg.configHome}/niri".enable;
        message = "dotfiles.programs.niri.enable requires the Niri configuration deployment to remain enabled.";
      }
      {
        assertion = !noctaliaCfg.enable || noctalia.enable;
        message = "dotfiles.programs.niri.noctalia.enable requires programs.noctalia.enable.";
      }
    ];

    xdg.configFile."niri" = {
      source = niriConfig;
      recursive = true;
    };
  };
}
