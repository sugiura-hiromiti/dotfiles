{
  config,
  lib,
  pkgs,
  theme,
  ...
}:
let
  cfg = config.dotfiles.programs.kitty;
  kitty = lib.getExe config.dotfiles.terminalProviders.kitty.package;
in
{
  options = {
    dotfiles = {
      programs = {
        kitty = {
          enable = lib.mkEnableOption "kitty terminal emulator";
        };
      };
    };
  };
  config = lib.mkMerge [
    {
      dotfiles = {
        # TODO: has_hotkey_window(仮称)optionを追加してiterm2のfloating terminalに相当する機能を実現できるterminalに対してはniri integrationも含めて機能を提供できるようにする
        terminalProviders = {
          kitty = {
            package = pkgs.kitty;
            appId = "kitty";
            mkCommand =
              {
                appId ? null,
                ...
              }:
              lib.escapeShellArgs (
                [ kitty ]
                ++ lib.optionals (appId != null) [
                  "--app-id"
                  appId
                ]
              );
          };
        };
      };
    }
    (lib.mkIf cfg.enable {
      catppuccin = {
        kitty = {
          enable = false;
        };
      };
      programs = {
        kitty = {
          package = null;
          themeFile = if theme == "light" then "Catppuccin-Latte" else "Catppuccin-Mocha";
          enable = true;
          settings = {
            enabled_layouts = "grid";
            font_size = 12;
            hide_window_decorations = true;
            text_composition_strategy = "1 100";
            background_opacity = 0.83;
            font_family = "family='PlemolJP Console NF' postscript_name=PlemolJPConsoleNF-ExtraLight";
            bold_font = "family='PlemolJP Console NF' postscript_name=PlemolJPConsoleNF-Light";
            italic_font = "family='PlemolJP Console NF' postscript_name=PlemolJPConsoleNF-ExtraLightItalic";
            bold_italic_font = "family='PlemolJP Console NF' postscript_name=PlemolJPConsoleNF-LightItalic";
            shell_integration = "no-rc";
          };
          quickAccessTerminalConfig = {
            background_opacity = 0.6;
            edge = "center";
            margin_left = 100;
            margin_right = 100;
            margin_top = 100;
            margin_bottom = 100;
            kitty_conf = "${pkgs.writeText "kitty-quick.conf" ''
              include ${config.xdg.configHome}/kitty/kitty.conf
              include ${pkgs.kitty-themes}/share/kitty-themes/themes/Catppuccin-Frappe.conf
            ''}";
          };
        };
      };
    })
  ];
}
