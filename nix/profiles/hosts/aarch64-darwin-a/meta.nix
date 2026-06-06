let
  personalIdentity = import ../../identities/sugiura-hiromiti.nix;
in
{
  system = "aarch64-darwin";
  accounts = {
    primary = "a";
    users = {
      a = personalIdentity // {
        uid = 501;
      };
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
}
