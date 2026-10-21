{
  config,
  lib,
  pkgs,
  ...
}:
let
  rev = "7e5c7b443e02995aad6d78ce10a3d307d6c010b6";
  baseUrl =
    "https://raw.githubusercontent.com/"
    + "AntoineBalaine/vscode-reascript-extension/"
    + rev
    + "/resources";
in
{
  config = lib.mkIf config.dotfiles.programs.reaper.enable {
    xdg.dataFile = {
      "reaper-lua-types/reaper.lua".source = pkgs.fetchurl {
        url = "${baseUrl}/Sexan_reaper_defs.lua";
        hash = "sha256-AohDkfbKra0SP99vAc2EygyFPinPu9pDVfYxF2gyga8=";
      };

      "reaper-lua-types/imgui.lua".source = pkgs.fetchurl {
        url = "${baseUrl}/imgui_defs_0.10.lua";
        hash = "sha256-cMNVPCwFTYaACpXKDWcRi2hHUrb+70uPqnbl73cT1Fg=";
      };
    };
  };
}
