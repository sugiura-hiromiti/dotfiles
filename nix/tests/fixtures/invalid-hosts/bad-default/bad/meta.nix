{
  system = "aarch64-linux";
  targets = [ "nixos" ];
  deployments.vm.modules = [ ];
  defaultDeployment = "missing";
  accounts = {
    primary = "admin";
    users.admin.uid = 1000;
  };
}
