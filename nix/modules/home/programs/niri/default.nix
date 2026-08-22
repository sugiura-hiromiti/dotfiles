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
  niriConfig =
    pkgs.runCommandLocal "niri-config"
      {
        inherit
          terminalKeybind
          terminalStartup
          floatingTerminalWindowRule
          ;
      }
      ''
        mkdir -p "$out"
        cp -R "${./config}/." "$out/"
        chmod -R u+w "$out"
        substituteInPlace "$out/config.kdl" \
          --replace-fail "~/Downloads/media/screenshots" "${paths.screenshotDirectory}" \
          --replace-fail "@terminalStartup@" "$terminalStartup" \
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
    xdg.configFile."niri" = {
      source = niriConfig;
      recursive = true;
    };
  };
}
