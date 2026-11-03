{ lib, ... }:
{
  dotfiles.darwin.homebrew = {
    enable = lib.mkDefault true;
    casks = [
      "raycast"
      "homerow"
      "docker-desktop"
      "BarutSRB/tap/omniwm"
      "krita"
      "obs"
      "distroav/tap/distroav"
    ];
    taps = [
      "BarutSRB/tap"
      "distroav/tap"
    ];
  };
}
