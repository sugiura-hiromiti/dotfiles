{
  config,
  lib,
  primaryAccountName,
  ...
}:
let
  cfg = config.dotfiles.darwin.core;
in
{
  options.dotfiles.darwin.core = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to configure baseline nix-darwin system settings.";
    };

    stateVersion = lib.mkOption {
      type = lib.types.int;
      default = 6;
      description = "nix-darwin state version for baseline hosts.";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.enable = lib.mkDefault false;

    system = {
      primaryUser = lib.mkDefault primaryAccountName;
      inherit (cfg) stateVersion;
    };
  };
}
