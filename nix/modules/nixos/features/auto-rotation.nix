{ config, lib, ... }:
let
  cfg = config.dotfiles.features.autoRotation;
  validPollingSensorName =
    cfg.pollingSensorName == null || builtins.match "^[A-Za-z0-9_.-]+$" cfg.pollingSensorName != null;
in
{
  options = {
    dotfiles = {
      features = {
        autoRotation = {
          enable = lib.mkEnableOption "automatic screen rotation";
          monitor = lib.mkOption {
            type = lib.types.nullOr lib.types.nonEmptyStr;
            default = null;
            example = "eDP-1";
            description = "Output connector to rotate. Required when automatic rotation is enabled.";
          };
          pollingSensorName = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "accel_3d";
            description = "IIO sensor requiring the polling workaround, or null when unnecessary.";
          };
        };
      };
    };
  };
  config = {
    assertions = [
      {
        assertion = !cfg.enable || cfg.monitor != null;
        message = "dotfiles.features.autoRotation.monitor must be set when automatic rotation is enabled.";
      }
      {
        assertion = validPollingSensorName;
        message = "dotfiles.features.autoRotation.pollingSensorName must be null or match ^[A-Za-z0-9_.-]+$.";
      }
    ];
    services = lib.mkIf cfg.enable {
      iio-niri = {
        enable = true;
        extraArgs = lib.optionals (cfg.monitor != null) [
          "--monitor"
          cfg.monitor
        ];
      };
      udev = {
        extraRules = lib.mkIf (cfg.pollingSensorName != null && validPollingSensorName) ''
          SUBSYSTEM=="iio", KERNEL=="iio:device*", ATTR{name}=="${cfg.pollingSensorName}", ENV{IIO_SENSOR_PROXY_TYPE}="iio-poll-accel"
        '';
      };
    };
  };
}
