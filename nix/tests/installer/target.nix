{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/testing/test-instrumentation.nix")
  ];
  system.stateVersion = "26.05";
  networking.hostName = "installed-dotfiles";
  users = {
    users = {
      operator = {
        isNormalUser = true;
        uid = 1441;
        group = "operators";
        home = "/srv/operator";
        extraGroups = [ "wheel" ];
      };
      root.initialHashedPassword = lib.mkForce null;
    };
    groups.operators.gid = 1442;
  };
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = true;
  services.getty.autologinUser = lib.mkForce null;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = lib.mkForce [ ];
    connect-timeout = 1;
  };
}
