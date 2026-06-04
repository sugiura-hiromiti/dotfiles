{
  pkgs,
  lib,
  config,
  ...
}:
let
  dotfilesRoot = "${config.home.homeDirectory}/dotfiles";
in
{
  home.packages =
    with pkgs;
    [
      reaper
      dexed
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      geonkick
      synthv1
      lsp-plugins
      calf
      helm
      cardinal
    ];

  xdg.configFile = lib.mkIf pkgs.stdenv.isLinux {
    geonkick.source = config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/geonkick";
  };
}
