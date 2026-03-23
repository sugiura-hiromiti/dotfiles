{
  pkgs,
  user,
  lib,
  config,
  ...
}:
{
  home.homeDirectory = lib.mkDefault "/Users/${user}";
  home.sessionVariables.LIBSQLITE = "${pkgs.sqlite.out}/lib/libsqlite3.dylib";
  programs.nushell.environmentVariables.LIBSQLITE = "${pkgs.sqlite.out}/lib/libsqlite3.dylib";

  home.file = {

    "nushell_appsupport_config" = {
      target = "Library/Application Support/nushell/config.nu";
      source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/nushell/config.nu";
    };
  };
  home.packages = with pkgs; [
    # tart
    # raycast
    betterdisplay
    reaper
    ghostty-bin
    # paneru.packages.${pkgs.system}.paneru
  ];
  services = {
    # paneru = {
    #   enable = true;
    #   settings = {
    #     options = {
    #       preset_column_widths = [
    #         0.3
    #         0.5
    #         0.7
    #         1.0
    #       ];
    #       # swipe_gesture_fingers = 4;
    #       # border_active_window = true;
    #     };
    #     swipe = {
    #       gesture = {
    #         fingers_count = 4;
    #         direction = "Natural";
    #       };
    #     };
    #     bindings = {
    #       window_focus_west = "cmd - h";
    #       window_focus_east = "cmd - l";
    #       window_focus_north = "cmd - j";
    #       window_focus_south = "cmd - k";
    #       window_swap_west = "cmd + ctrl - h";
    #       window_swap_east = "cmd + ctrl - l";
    #       window_swap_north = "cmd + ctrl - j";
    #       window_swap_south = "cmd + ctrl - k";
    #       window_center = "cmd + ctrl - c";
    #       window_resize = "cmd - r";
    #       window_manage = "cmd + ctrl - v";
    #       window_stack = "cmd - ;";
    #       window_unstack = "cmd - '";
    #       window_nextdisplay = "alt - a";
    #       mouse_nextdisplay = "alt + shift - a";
    #     };
    #     windows = {
    #       pip = {
    #         title = "Picture.*(in)?.*[Pp]icture";
    #         floating = true;
    #       };
    #     };
    #   };
    # };
  };
  programs = {
    firefox = {
      enable = true;
      policies = {
        AutofillAddressEnabled = true;
        AutofillCreditCardEnabled = true;
        DisableAppUpdate = true;
        DisableFeedbackCommand = false;
        DisableFirefoxStudies = false;
        DisablePocket = true;
        DisableTelemetry = false;
        DontCheckDefaultBrowser = true;
        NoDefaultBookmarks = true;
        OfferToSaveLogins = true;
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
      };
      profiles = {
        dflt = {
          isDefault = true;
          id = 0;
          extensions = {
            force = true;
            # packages = with pkgs.nur.repos.rycee.firefox-addons; [ vimium-c ];
          };
          settings = {
            "browser.startup.homepage" = "https://www.google.com";
            "browser.toolbars.bookmarks.visibility" = "never";
            "browser.bookmarks.restore_default_bookmarks" = false;
            "browser.bookmarks.showMobileBookmarks" = false;
            "browser.crashReports.unsubmittedCheck.autoSubmit2" = true;
            "browser.search.region" = "US";
            "browser.toolbarbuttons.introduced.sidebar-button" = false;
            "sidebar.main.tools" = "syncedtabs,bookmarks,passwords";
            "sidebar.verticalTabs" = false;
            "sidebar.visibility" = "hide-sidebar";
            "widget.use-xdg-desktop-portal.file-picker" = 1;
            "widget.use-xdg-desktop-portal.mime-handler" = 1;
            "widget.use-xdg-desktop-portal.settings" = 1;
            "widget.use-xdg-desktop-portal.open-url" = 1;
          };
        };
      };
    };
  };
}
