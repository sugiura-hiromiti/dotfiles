{
  config,
  host ? null,
  hostName ? null,
  lib,
  ...
}:
let
  cfg = config.dotfiles.nixos.networking;
in
{
  options.dotfiles.nixos.networking.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure baseline host networking.";
  };

  config = lib.mkIf cfg.enable {
    networking = {
      hostName = lib.mkDefault (
        if hostName != null then
          hostName
        else if host != null then
          host
        else
          "nixos"
      );

      networkmanager.enable = lib.mkDefault true;

      firewall.allowedTCPPorts = [ 22 ];
    };
  };
}
