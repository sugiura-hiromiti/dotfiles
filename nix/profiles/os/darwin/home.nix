{
  accountName,
  account ? { },
  lib,
  ...
}:
let
  configuredHomeDirectory = account.homeDirectory or null;
  homeDir =
    if configuredHomeDirectory != null then configuredHomeDirectory else "/Users/${accountName}";
in
{
  home.homeDirectory = lib.mkDefault homeDir;
  dotfiles.features.darwinApps.enable = lib.mkDefault true;
}
