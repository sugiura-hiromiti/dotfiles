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
  regularCommand = provider.mkCommand { inherit (terminal.role.regular) appId; };
  paths = config.dotfiles.paths;
  terminalCfg = cfg.terminal;
  kdlString = builtins.toJSON;
  regexFor = value: "^${lib.escapeRegex value}$";
  shellSpawnArgs = command: ''"sh" "-lc" ${kdlString command}'';
  terminalStartup = lib.optionalString (
    terminalCfg.enable && terminalCfg.startup.enable
  ) "spawn-at-startup ${shellSpawnArgs regularCommand}";
  terminalWindowRule =
    lib.optionalString
      (
        terminalCfg.enable
        && terminalCfg.transientWindowRule.enable
        && terminal.role.transient.appId != null
      )
      (
        lib.concatStringsSep "\n" [
          "window-rule {"
          "    match app-id=${kdlString (regexFor terminal.role.transient.appId)}"
          "    open-floating true"
          "    default-column-width { proportion 0.8; }"
          "    default-window-height { proportion 0.6; }"
          "}"
        ]
      );
  terminalKeybind = lib.optionalString (
    terminalCfg.enable && terminalCfg.keybind.enable
  ) "    Mod+T hotkey-overlay-title=\"Open a Terminal\" { spawn ${shellSpawnArgs regularCommand}; }";
  niriConfig =
    pkgs.runCommandLocal "niri-config"
      {
        inherit
          terminalKeybind
          terminalStartup
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
        default = true;
        description = "Whether to generate niri integration for the configured terminal provider.";
      };

      startup.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether niri opens the configured terminal at startup.";
      };

      transientWindowRule.enable = lib.mkOption {
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
    xdg.configFile."niri" = {
      source = niriConfig;
      recursive = true;
    };
  };
}
