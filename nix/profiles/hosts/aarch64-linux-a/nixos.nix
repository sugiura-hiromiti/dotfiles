{ pkgs, user, ... }:
{
  imports = [ ./hardware-configuration.nix ];
  users.users.${user} = {
    isNormalUser = true;
    description = user;
    extraGroups = [
      "networkmanager"
      "wheel"
      "inputs"
    ];
    packages = with pkgs; [ ];
    shell = pkgs.nushell;
    openssh = {
      authorizedKeys = {
        keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8t5TzxjrjRbwyCUZLKrYAK8Yl1g5qmolDF/cHUq0ro android"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID/SVDZ/Jc53n3NbfQMadDpq5cmtRvjBzLXrVE8NzW1m ios"
        ];
      };
    };
  };
}
