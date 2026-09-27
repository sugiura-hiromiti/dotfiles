{
  system = "aarch64-darwin";
  targets = [ "darwin" ];
  deployments = {
    first.modules = [ ];
    second.modules = [ ];
  };
  accounts = {
    primary = "admin";
    users.admin.uid = 501;
  };
}
