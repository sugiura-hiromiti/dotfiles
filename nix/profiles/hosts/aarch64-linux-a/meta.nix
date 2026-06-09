let
  personalIdentity = import ../../identities/sugiura-hiromiti.nix;
in
{
  system = "aarch64-linux";
  hostName = "nixos";
  accounts = {
    primary = "a";
    users = {
      a = personalIdentity // {
        extraGroups = [
          "networkmanager"
          "wheel"
          "inputs"
        ];
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8t5TzxjrjRbwyCUZLKrYAK8Yl1g5qmolDF/cHUq0ro android"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID/SVDZ/Jc53n3NbfQMadDpq5cmtRvjBzLXrVE8NzW1m ios"
        ];
      };
    };
  };
  targets = [
    "home"
    "nixos"
  ];
  roles = [ ];
  variants = [
    "ai-tools"
    "dtm"
    "media"
    "noctalia-shell"
    "terminal"
    "game"
  ];
  runtime = {
    themes = [
      "dark"
      "light"
    ];
    sessions = [
      "gui"
      "tty"
    ];
    targetAxes = {
      theme = true;
      session = true;
    };
  };
}
