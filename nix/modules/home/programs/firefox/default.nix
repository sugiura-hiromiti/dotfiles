{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.firefox;
  firefoxAddons = pkgs.nur.repos.rycee.firefox-addons;
in
{
  options.dotfiles.programs.firefox = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable Firefox.";
    };

    addons = {
      force = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to remove Firefox add-ons not listed in Nix configuration.";
      };

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [
          firefoxAddons.firefox-color
          firefoxAddons.bitwarden
          firefoxAddons.darkreader
          firefoxAddons.ff2mpv
          firefoxAddons.org-capture
          firefoxAddons.vimium-c
        ];
        defaultText = lib.literalExpression ''
          with pkgs.nur.repos.rycee.firefox-addons; [
            firefox-color
            bitwarden
            darkreader
            ff2mpv
            org-capture
            vimium-c
          ]
        '';
        example = lib.literalExpression ''
          with pkgs.nur.repos.rycee.firefox-addons; [
            firefox-color
            bitwarden
            darkreader
            ff2mpv
            org-capture
            vimium-c
            ublock-origin
          ]
        '';
        description = "Firefox add-on packages to install in the default profile.";
      };
    };
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
        extensions.force = cfg.addons.force;
        extensions.packages = cfg.addons.packages;
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
