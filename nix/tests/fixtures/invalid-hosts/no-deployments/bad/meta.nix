{
  system = "aarch64-linux";
  targets = [ "nixos" ];
  accounts = {
    primary = "admin";
    users.admin.uid = 1000;
  };
}
