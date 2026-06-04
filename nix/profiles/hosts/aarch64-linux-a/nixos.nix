{
  lib,
  pkgs,
  accounts,
  ...
}:
let
  mkUser = name: account: {
    isNormalUser = true;
    description = account.description or name;
    inherit (account) extraGroups;
    packages = with pkgs; [ ];
    shell = pkgs.nushell;
    openssh.authorizedKeys.keys = account.authorizedKeys or [ ];
  };
in
{
  imports = [ ./hardware-configuration.nix ];
  users.users = lib.mapAttrs mkUser accounts.users;
}
