let
  personalIdentity = import ../../identities/sugiura-hiromiti.nix;
in
{
  system = "x86_64-linux";
  hostName = "thinkpad-x12";
  # deployments.parallels.modules = [ ];
  # deployments.qemu.modules = [ ./deployments/qemu/nixos.nix ];
  deployments = {
    # parallels = {
    #   modules = [ ];
    # };
    # qemu = {
    #   modules = [ ];
    # };
    native = {
      modules = [ ];
    };
  };
  defaultDeployment = "native";
  accounts = {
    primary = "a";
    users = {
      a = personalIdentity // {
        uid = 1000;
        extraGroups = [
          "networkmanager"
          "wheel"
          "inputs"
        ];
        authorizedKeys = [
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
