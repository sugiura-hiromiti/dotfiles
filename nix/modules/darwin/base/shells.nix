{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.darwin.shells;
in
{
  options.dotfiles.darwin.shells.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install baseline login shells on Darwin hosts.";
  };

  config = lib.mkIf cfg.enable {
    environment = {
      shells = [
        pkgs.nushell
      ];

      systemPackages = [
        pkgs.nushell
      ];
    };
  };
}
