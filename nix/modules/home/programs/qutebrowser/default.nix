{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.qutebrowser;
  isDark = config.catppuccin.flavor != "latte";
in
{
  options = {
    dotfiles = {
      programs = {
        qutebrowser = {
          enable = lib.mkEnableOption "qutebrowser";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    programs = {
      qutebrowser = {
        enable = true;
        loadAutoconfig = false;
        keyBindings = {
          normal = {
            ",m" = "spawn --detach mpv {url}";
            f = "hint all";
            F = "hint --rapid links tab-bg";
            g = "scroll top";
            G = "scroll bottom";
            j = "scroll down";
            k = "scroll up";
            h = "scroll left";
            l = "scroll right";
            a = "mode-enter insert";
            i = "hint inputs";
            r = "reload";
            c = "yank url";
            v = "mode-enter caret";
            q = "tab-prev";
            w = "tab-next";
            d = "tab-clone";
            x = "tab-close --prev";
            X = "undo";
            o = "cmd-set-text -s :open";
            O = "cmd-set-text -s :open -t";
            b = "cmd-set-text -s :bookmark-load";
            B = "cmd-set-text -s :bookmark-load -t";
            t = "cmd-set-text -s :tab-select";
            "/" = "cmd-set-text /";
            n = "search-next";
            N = "search-prev";
            H = "back";
            L = "forward";
            T = "tab-give";
            "<Shift-comma>" = "tab-move -";
            "<Shift-period>" = "tab-move +";
            "?" = "help";
            ":" = "cmd-set-text :";
          };
        };
        searchEngines = {
          DEFAULT = "https://www.google.com/search?q={}";
        };
        settings = {
          auto_save = {
            session = true;
          };
          url = {
            default_page = "https://www.google.com";
            start_pages = [ "https://www.google.com" ];
          };
          tabs = {
            position = "bottom";
          };
          colors = {
            webpage = {
              preferred_color_scheme = if isDark then "dark" else "light";
              darkmode = {
                enabled = isDark;
              };
            };
          };
        };
      };
    };
  };
}
