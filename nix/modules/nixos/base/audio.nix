{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.nixos.audio;
in
{
  options.dotfiles.nixos.audio.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure the baseline PipeWire audio stack.";
  };

  config = lib.mkIf cfg.enable {
    services.pipewire = {
      enable = lib.mkDefault true;
      alsa = {
        enable = lib.mkDefault true;
        support32Bit = lib.mkDefault false;
      };
      pulse.enable = lib.mkDefault true;
    };

    security.rtkit.enable = lib.mkDefault true;

    environment.systemPackages = [
      pkgs.pipewire
    ];
  };
}
