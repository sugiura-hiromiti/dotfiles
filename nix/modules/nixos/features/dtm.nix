{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.dtm;
in
{
  options.dotfiles.features.dtm = {
    enable = lib.mkEnableOption "digital music production system integration";

    jack.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable PipeWire JACK compatibility.";
    };

    alsaTuning = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to apply DTM-oriented WirePlumber ALSA tuning.";
      };
      periodSize = lib.mkOption {
        type = lib.types.int;
        default = 2048;
        description = "ALSA period size applied to ALSA output nodes.";
      };
      headroom = lib.mkOption {
        type = lib.types.int;
        default = 8192;
        description = "ALSA headroom applied to ALSA output nodes.";
      };
    };

    buffer = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to apply DTM-oriented PipeWire buffer settings.";
      };
      defaultRate = lib.mkOption {
        type = lib.types.int;
        default = 48000;
        description = "Default PipeWire clock rate.";
      };
      allowedRates = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [
          44100
          48000
        ];
        description = "Allowed PipeWire clock rates.";
      };
      quantum = lib.mkOption {
        type = lib.types.int;
        default = 512;
        description = "Default PipeWire quantum.";
      };
      minQuantum = lib.mkOption {
        type = lib.types.int;
        default = 256;
        description = "Minimum PipeWire quantum.";
      };
      maxQuantum = lib.mkOption {
        type = lib.types.int;
        default = 1024;
        description = "Maximum PipeWire quantum.";
      };
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        pipewire.jack
        jack2
        jack-example-tools
      ];
      description = "System-level DTM audio packages.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.pipewire.jack.enable = cfg.jack.enable;
        environment.systemPackages = cfg.packages;
      }

      (lib.mkIf cfg.alsaTuning.enable {
        services.pipewire.wireplumber.extraConfig."50-alsa-config"."monitor.alsa.rules" = [
          {
            matches = [ { "node.name" = "~alsa_output.*"; } ];
            actions.update-props = {
              "api.alsa.period-size" = cfg.alsaTuning.periodSize;
              "api.alsa.headroom" = cfg.alsaTuning.headroom;
            };
          }
        ];
      })

      (lib.mkIf cfg.buffer.enable {
        services.pipewire.extraConfig.pipewire."10-buffer"."context.properties" = {
          "default.clock.rate" = cfg.buffer.defaultRate;
          "default.clock.allowed-rates" = cfg.buffer.allowedRates;
          "default.clock.quantum" = cfg.buffer.quantum;
          "default.clock.min-quantum" = cfg.buffer.minQuantum;
          "default.clock.max-quantum" = cfg.buffer.maxQuantum;
        };
      })
    ]
  );
}
