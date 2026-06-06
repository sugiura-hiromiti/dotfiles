{
  accountName,
  pkgs,
  config,
  lib,
  ...
}:
let
  mypkgs = import ../pkg {
    inherit pkgs;
  };
in
{
  nixpkgs.config.allowUnfree = true;

  catppuccin = {
    enable = true;
    autoEnable = lib.mkDefault false;
  };

  home = {
    username = accountName;
    stateVersion = "26.05";
    sessionVariables = {
      XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
      XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
      XDG_STATE_HOME = "${config.home.homeDirectory}/.local/state";
      XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
    };
    packages = mypkgs;
  };

  xdg.enable = true;
}
