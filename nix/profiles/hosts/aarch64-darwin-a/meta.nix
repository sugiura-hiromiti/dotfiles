{
  system = "aarch64-darwin";
  accounts = {
    primary = "a";
    users = {
      a = {
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
  ];
}
