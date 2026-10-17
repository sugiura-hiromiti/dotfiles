{ pkgs }:
let
  addons = pkgs.nur.repos.rycee.firefox-addons;
in
{
  policies = {
    DisablePocket = true;
    DontCheckDefaultBrowser = true;
    DisableAppUpdate = true;

    EnableTrackingProtection = {
      Value = true;
      Locked = true;
      Cryptomining = true;
      Fingerprinting = true;
    };

    # 既存の他の policies もここへ移動
  };

  settings = {
    "browser.startup.page" = 3;
    "browser.startup.homepage" = "https://www.google.com";

    "widget.use-xdg-desktop-portal.file-picker" = 1;
    "widget.use-xdg-desktop-portal.mime-handler" = 1;
    "widget.use-xdg-desktop-portal.settings" = 1;
    "widget.use-xdg-desktop-portal.open-url" = 1;

    # 既存の他の共通 settings もここへ移動
  };

  extensions = [
    addons.bitwarden
    addons.darkreader
    addons.ff2mpv
    addons.org-capture
  ];
}
