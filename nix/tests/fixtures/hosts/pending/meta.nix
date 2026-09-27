{
  system = "aarch64-linux";
  targets = [ "nixos" ];
  deployments.vm.modules = [ ];
  defaultDeployment = "vm";
  accounts = {
    primary = "admin";
    users.admin.uid = 1000;
  };
}
