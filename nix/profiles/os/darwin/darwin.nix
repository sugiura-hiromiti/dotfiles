{ lib, ... }:
{
  dotfiles.darwin.homebrew = {
    enable = lib.mkDefault true;
    casks = [
      "raycast"
      "homerow"
      "docker-desktop"
      "BarutSRB/tap/omniwm"
    ];
    taps = [
      "BarutSRB/tap"
    ];
  };
}
