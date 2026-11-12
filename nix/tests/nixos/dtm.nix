{
  lib,
  pkgs,
}:
let
  evaluate =
    settings:
    (lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../../modules/nixos/features/dtm.nix
        {
          boot.isContainer = true;
          system.stateVersion = "26.05";
        }
        settings
      ];
    }).config;

  contains = package: packages: lib.elem (toString package) (map toString packages);

  check =
    name: settings: expected:
    let
      config = evaluate settings;
      want = {
        feature = true;
        jack = true;
        pipewire = true;
        audio = true;
        jackPackage = true;
        tools = true;
        customPackages = [ ];
      }
      // expected;
    in
    assert lib.assertMsg (
      config.dotfiles.features.dtm.enable == want.feature
    ) "${name}: unexpected DTM feature activation";
    assert lib.assertMsg (
      config.dotfiles.features.dtm.jack.enable == want.jack
    ) "${name}: unexpected public JACK compatibility selection";
    assert lib.assertMsg (
      config.services.pipewire.enable == want.pipewire
      && config.services.pipewire.audio.enable == want.audio
    ) "${name}: unexpected PipeWire audio startup";
    assert lib.assertMsg (
      !config.services.pipewire.jack.enable
    ) "${name}: deprecated global PipeWire JACK compatibility was enabled";
    assert lib.assertMsg (
      !(config.environment.sessionVariables ? LD_LIBRARY_PATH)
    ) "${name}: JACK compatibility leaked into the global library search path";
    assert lib.assertMsg (lib.all (
      warning: !(lib.hasInfix "services.pipewire.jack.enable" warning)
    ) config.warnings) "${name}: deprecated PipeWire JACK option produced a warning";
    assert lib.assertMsg (
      contains pkgs.pipewire.jack config.environment.systemPackages == want.jackPackage
    ) "${name}: unexpected pw-jack installation";
    assert lib.assertMsg (
      contains pkgs.jack2 config.environment.systemPackages == want.tools
      && contains pkgs.jack-example-tools config.environment.systemPackages == want.tools
    ) "${name}: unexpected default JACK tool installation";
    assert lib.assertMsg (lib.all (
      package: contains package config.environment.systemPackages
    ) want.customPackages) "${name}: custom system DTM packages were lost";
    true;

  cases = [
    (check "disabled feature contributes no JACK setup" { } {
      feature = false;
      pipewire = false;
      audio = false;
      jackPackage = false;
      tools = false;
    })
    (check "enabled JACK starts PipeWire audio and installs pw-jack" {
      dotfiles.features.dtm.enable = true;
    } { })
    (check "JACK opt-out preserves tools without enabling PipeWire audio"
      {
        dotfiles.features.dtm = {
          enable = true;
          jack.enable = false;
        };
      }
      {
        jack = false;
        pipewire = false;
        audio = false;
        jackPackage = false;
      }
    )
    (check "custom package selection still supplies requested JACK compatibility"
      {
        dotfiles.features.dtm = {
          enable = true;
          packages = [ pkgs.hello ];
        };
      }
      {
        tools = false;
        customPackages = [ pkgs.hello ];
      }
    )
    (check "JACK opt-out preserves custom package selection"
      {
        dotfiles.features.dtm = {
          enable = true;
          jack.enable = false;
          packages = [ pkgs.hello ];
        };
      }
      {
        jack = false;
        pipewire = false;
        audio = false;
        jackPackage = false;
        tools = false;
        customPackages = [ pkgs.hello ];
      }
    )
    (check "disabled feature preserves independent audio configuration"
      {
        services.pipewire = {
          enable = true;
          audio.enable = true;
        };
        environment.systemPackages = [ pkgs.hello ];
      }
      {
        feature = false;
        jackPackage = false;
        tools = false;
        customPackages = [ pkgs.hello ];
      }
    )
    (check "explicit PipeWire audio opt-out overrides the DTM default" {
      dotfiles.features.dtm.enable = true;
      services.pipewire.audio.enable = false;
    } { audio = false; })
  ];
in
assert lib.all (result: result) cases;
pkgs.runCommandLocal "dtm-nixos-eval-test" { } ''touch "$out"''
