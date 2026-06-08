let
  personalIdentity = import ../../identities/sugiura-hiromiti.nix;
in
{
  system = "aarch64-darwin";
  accounts = {
    primary = "hiromichisugiura";
    users = {
      hiromichisugiura = personalIdentity;
    };
  };
  targets = [
    "home"
    "darwin"
  ];
  roles = [ ];
  variants = [
    "ai-tools"
    "media"
    "terminal"
  ];
  runtime = {
    themes = [
      "dark"
      "light"
    ];
    sessions = [ "gui" ];
    targetAxes = {
      theme = true;
      session = false;
    };
  };
}
