{
  config,
  lib,
  nixPackage,
  ...
}:
let
  cfg = config.dotfiles.darwin.core;
in
{
  options = {
    dotfiles = {
      darwin = {
        core = {
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
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nix = {
      package = lib.mkDefault nixPackage;
      enable = lib.mkDefault true;
      linux-builder = {
        enable = true;
        systems = lib.unique [
          config.nix.linux-builder.package.nixosConfig.nixpkgs.hostPlatform.system
          "x86_64-linux"
        ];
        supportedFeatures = [
          "kvm"
          "benchmark"
          "big-parallel"
          "nixos-test"
        ];
        config.boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
        config.virtualisation = {
          darwin-builder = {
            memorySize = 8 * 1024;
            diskSize = 256 * 1024;
          };
          fileSystems."/".autoResize = true;
        };
      };
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
    system = {
      inherit (cfg) stateVersion;
    }
    // lib.optionalAttrs (cfg.primaryUser != null) {
      primaryUser = lib.mkDefault cfg.primaryUser;
    };
  };
}
