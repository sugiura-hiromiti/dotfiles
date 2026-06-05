{
  config,
  lib,
  pkgs,
  system,
  theme,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optional
    optionals
    types
    ;
  cfg = config.dotfiles.features.noctaliaShell;
  terminalCommand =
    if cfg.terminal.command != null then
      cfg.terminal.command
    else if cfg.terminal.package != null then
      "${lib.getExe cfg.terminal.package} start"
    else if config.dotfiles.features.terminal.enable then
      config.dotfiles.features.terminal.command
    else
      "wezterm start";
  settings = import ./noctalia-shell/settings.nix {
    inherit
      config
      cfg
      lib
      terminalCommand
      theme
      ;
  };
in
{
  options.dotfiles.features.noctaliaShell = {
    enable = mkEnableOption "Noctalia Shell";

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = "Noctalia Shell package. Defaults to pkgs.noctalia-shell with calendar support matching the feature setting.";
    };

    calendar.enable = mkEnableOption "Noctalia calendar integration";
    clipboard.enable = mkEnableOption "Noctalia clipboard history integration";
    ddc.enable = mkEnableOption "Noctalia DDC brightness integration";
    screenToolkit.enable = mkEnableOption "Noctalia screen toolkit plugin";
    visualizer.enable = mkEnableOption "Noctalia audio visualizer integration";
    wallpaper.enable = mkEnableOption "Noctalia wallpaper integration";

    terminal = {
      package = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = "Optional terminal package installed for Noctalia app launcher. Null delegates installation to dotfiles.features.terminal.";
      };
      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Terminal command used by Noctalia app launcher. When null, this is derived from terminal.package.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasSuffix "-linux" system;
        message = "dotfiles.features.noctaliaShell is Linux-only.";
      }
    ];

    home.packages =
      optional (cfg.terminal.package != null) cfg.terminal.package
      ++ optionals cfg.calendar.enable [
        pkgs.evolution-data-server
      ]
      ++ optionals cfg.clipboard.enable [
        pkgs.wl-clipboard-rs
      ]
      ++ optionals cfg.ddc.enable [
        pkgs.ddcutil
      ]
      ++ optionals cfg.screenToolkit.enable [
        pkgs.grim
        pkgs.slurp
      ];

    programs.cava.enable = mkIf cfg.visualizer.enable true;

    services.cliphist = mkIf cfg.clipboard.enable {
      enable = true;
      clipboardPackage = pkgs.wl-clipboard-rs;
    };

    programs.noctalia-shell = {
      enable = true;
      package =
        if cfg.package != null then
          cfg.package
        else
          pkgs.noctalia-shell.override { calendarSupport = cfg.calendar.enable; };
      plugins = {
        sources = [
          {
            enabled = true;
            name = "official noctalia plugins";
            url = "https://github.com/noctalia-dev/noctalia-plugins";
          }
        ];
        states = {
          keybind-cheatsheet = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
        }
        // lib.optionalAttrs cfg.screenToolkit.enable {
          screen-toolkit = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
        };
        version = 2;
      };
      pluginSettings = { };
      inherit settings;
    };
  };
}
