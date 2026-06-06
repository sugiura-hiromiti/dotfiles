{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.nixos.remoteAccess;
in
{
  options.dotfiles.nixos.remoteAccess.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure baseline SSH and Tailscale services.";
  };

  config = lib.mkIf cfg.enable {
    services = {
      openssh = {
        enable = lib.mkDefault true;
        settings = {
          PasswordAuthentication = lib.mkDefault false;
          PermitRootLogin = lib.mkDefault "no";
          KbdInteractiveAuthentication = lib.mkDefault false;
        };
      };

      tailscale.enable = lib.mkDefault true;
    };

    environment.systemPackages = [
      pkgs.tailscale
    ];
  };
}
