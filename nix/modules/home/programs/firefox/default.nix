{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.firefox;
in
{
  options.dotfiles.programs.firefox.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to enable Firefox.";
  };

  config = lib.mkIf cfg.enable {
    programs.firefox = {
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
      profiles.dflt = {
        isDefault = true;
        extensions.force = true;
        settings = {
          "browser.startup.page" = 3;
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
}
