{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.nixos.core;
in
{
  options.dotfiles.nixos.core = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to configure baseline NixOS system settings.";
    };

    stateVersion = lib.mkOption {
      type = lib.types.str;
      default = "26.05";
      description = "NixOS state version for baseline hosts.";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = lib.mkDefault true;

    system = {
      autoUpgrade = {
        enable = lib.mkDefault true;
        allowReboot = lib.mkDefault true;
      };
      inherit (cfg) stateVersion;
    };

    nix.settings = {
      auto-optimise-store = lib.mkDefault true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    programs.nix-ld.enable = lib.mkDefault true;
  };
}
