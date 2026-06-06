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
  dotfiles.nixos.boot.performanceTuning.enable = lib.mkDefault true;
  users.users = lib.mapAttrs mkUser accounts.users;
}
