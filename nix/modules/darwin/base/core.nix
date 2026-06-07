{
  config,
  lib,
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

    primaryUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Primary nix-darwin user. Null leaves system.primaryUser unset.";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.enable = lib.mkDefault false;

    system = {
      inherit (cfg) stateVersion;
    }
    // lib.optionalAttrs (cfg.primaryUser != null) {
      primaryUser = lib.mkDefault cfg.primaryUser;
    };
  };
}
