{
  pkgs,
  lib,
  ...
}:
{
  dotfiles.programs.geonkick.enable = pkgs.stdenv.isLinux;

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
}
