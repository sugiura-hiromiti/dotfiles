{ lib, pkgs }:
let
  evaluate =
    feature: extra:
    (lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../../modules/nixos/features/auto-rotation.nix
        {
          boot.isContainer = true;
          system.stateVersion = "26.05";
          dotfiles.features.autoRotation = feature;
        }
        extra
      ];
    }).config;

  x12 = {
    enable = true;
    monitor = "eDP-1";
    pollingSensorName = "accel_3d";
  };
  enabled = evaluate x12 { };
  disabled = evaluate { } { };
  disabledWithMetadata = evaluate (x12 // { enable = false; }) { };
  withoutWorkaround = evaluate (x12 // { pollingSensorName = null; }) { };
  otherHost = evaluate {
    enable = true;
    monitor = "DSI-1";
    pollingSensorName = "other-accel.0";
  } { };
  missingMonitor = evaluate { enable = true; } { };

  externalRule = ''SUBSYSTEM=="input", ENV{AUTO_ROTATION_TEST}="1"'';
  externallyEnabled = evaluate (x12 // { enable = false; }) {
    services.iio-niri = {
      enable = true;
      extraArgs = [ "--external-arg" ];
    };
    services.udev.extraRules = externalRule;
  };

  hasPollingRule = config: lib.hasInfix "IIO_SENSOR_PROXY_TYPE" config.services.udev.extraRules;
  hasFailedAssertion =
    option: config:
    lib.any (entry: !entry.assertion && lib.hasInfix option entry.message) config.assertions;
  invalidSensors = map (name: evaluate (x12 // { pollingSensorName = name; }) { }) [
    ""
    "accel\"broken"
    "accel*"
    "accel\nbroken"
    "accel broken"
  ];
in
# Successful projections alone do not force NixOS assertions.
assert lib.all (config: lib.all (entry: entry.assertion) config.assertions) [
  enabled
  disabled
  disabledWithMetadata
  withoutWorkaround
  otherHost
  externallyEnabled
];
assert enabled.services.iio-niri.enable;
assert
  enabled.services.iio-niri.extraArgs == [
    "--monitor"
    "eDP-1"
  ];
assert lib.hasInfix
  ''SUBSYSTEM=="iio", KERNEL=="iio:device*", ATTR{name}=="accel_3d", ENV{IIO_SENSOR_PROXY_TYPE}="iio-poll-accel"''
  enabled.services.udev.extraRules;
assert !disabled.services.iio-niri.enable;
assert disabled.services.iio-niri.extraArgs == [ ];
assert !hasPollingRule disabled;
assert !disabledWithMetadata.services.iio-niri.enable;
assert disabledWithMetadata.services.iio-niri.extraArgs == [ ];
assert !hasPollingRule disabledWithMetadata;
assert withoutWorkaround.services.iio-niri.enable;
assert
  withoutWorkaround.services.iio-niri.extraArgs == [
    "--monitor"
    "eDP-1"
  ];
assert !hasPollingRule withoutWorkaround;
assert otherHost.services.iio-niri.enable;
assert
  otherHost.services.iio-niri.extraArgs == [
    "--monitor"
    "DSI-1"
  ];
assert lib.hasInfix ''ATTR{name}=="other-accel.0", ENV{IIO_SENSOR_PROXY_TYPE}="iio-poll-accel"''
  otherHost.services.udev.extraRules;
assert hasFailedAssertion "dotfiles.features.autoRotation.monitor" missingMonitor;
assert missingMonitor.services.iio-niri.extraArgs == [ ];
assert externallyEnabled.services.iio-niri.enable;
assert externallyEnabled.services.iio-niri.extraArgs == [ "--external-arg" ];
assert lib.hasInfix externalRule externallyEnabled.services.udev.extraRules;
assert !hasPollingRule externallyEnabled;
assert lib.all (hasFailedAssertion "dotfiles.features.autoRotation.pollingSensorName")
  invalidSensors;
assert lib.all (config: !hasPollingRule config) invalidSensors;
pkgs.runCommandLocal "auto-rotation-eval-test" { } ''touch "$out"''
