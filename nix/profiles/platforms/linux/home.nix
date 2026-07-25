{
  accountName,
  account ? { },
  lib,
  pkgs,
  ...
}:
let
  configuredHomeDirectory = account.homeDirectory or null;
  homeDir =
    if configuredHomeDirectory != null then configuredHomeDirectory else "/home/${accountName}";
in
{
  home.homeDirectory = lib.mkDefault homeDir;
  home.packages = with pkgs; [ wl-clipboard-rs ];
}
