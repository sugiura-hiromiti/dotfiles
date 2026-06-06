{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.darwin.remoteAccess;
in
{
  options.dotfiles.darwin.remoteAccess.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure baseline SSH and Tailscale services.";
  };

  config = lib.mkIf cfg.enable {
    services = {
      tailscale.enable = lib.mkDefault true;
      openssh.enable = lib.mkDefault true;
    };

    environment.systemPackages = [
      pkgs.tailscale
    ];
  };
}
