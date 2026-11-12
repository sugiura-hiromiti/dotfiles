{
  lib,
  pkgs,
  home-manager,
  reaper-flake,
}:
let
  evaluate =
    {
      settings,
      osConfig ? null,
    }:
    (home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {
        reaperFlake = reaper-flake;
      }
      // lib.optionalAttrs (osConfig != null) { inherit osConfig; };
      modules = [
        reaper-flake.homeModules.reaper
        ../../modules/home/base/paths.nix
        ../../modules/home/features/dtm.nix
        ../../modules/home/programs/reaper
        ../../modules/home/programs/geonkick
        {
          nixpkgs.config.allowUnfree = true;
          home = {
            username = "dtm-test";
            homeDirectory = "/home/dtm-test";
            stateVersion = "26.05";
          };
          dotfiles.features.dtm = {
            packages = lib.mkDefault [ ];
            linuxPackages = lib.mkDefault [ ];
          };
        }
        settings
      ];
    }).config;

  contains = package: packages: lib.elem (toString package) (map toString packages);

  check =
    name: arguments: expected:
    let
      config = evaluate arguments;
      want = {
        feature = true;
        jack = true;
        reaper = true;
        homeJack = true;
        reaperJack = true;
        customPackages = [ ];
        customReaperPackages = [ ];
      }
      // expected;
    in
    assert lib.assertMsg (
      config.dotfiles.features.dtm.enable == want.feature
    ) "${name}: unexpected DTM feature activation";
    assert lib.assertMsg (
      config.dotfiles.features.dtm.jack.enable == want.jack
    ) "${name}: unexpected JACK compatibility selection";
    assert lib.assertMsg (
      config.programs.reaper.enable == want.reaper
    ) "${name}: unexpected REAPER activation";
    assert lib.assertMsg (
      contains pkgs.pipewire.jack config.home.packages == want.homeJack
    ) "${name}: unexpected pw-jack installation";
    assert lib.assertMsg (
      contains pkgs.pipewire.jack config.programs.reaper.packages == want.reaperJack
    ) "${name}: unexpected REAPER JACK runtime libraries";
    assert lib.assertMsg (lib.all (
      package: contains package config.home.packages
    ) want.customPackages) "${name}: custom DTM packages were lost";
    assert lib.assertMsg (lib.all (
      package: contains package config.programs.reaper.packages
    ) want.customReaperPackages) "${name}: custom REAPER runtime libraries were lost";
    assert lib.assertMsg (
      !(config.home.sessionVariables ? LD_LIBRARY_PATH)
    ) "${name}: JACK compatibility leaked into the global library search path";
    true;

  cases = [
    (check "disabled feature contributes no JACK setup" { settings = { }; } {
      feature = false;
      reaper = false;
      homeJack = false;
      reaperJack = false;
    })
    (check "standalone Linux enables JACK compatibility by default" {
      settings.dotfiles.features.dtm.enable = true;
    } { })
    (check "JACK opt-out retains REAPER without JACK runtime libraries"
      {
        settings.dotfiles.features.dtm = {
          enable = true;
          jack.enable = false;
        };
      }
      {
        jack = false;
        homeJack = false;
        reaperJack = false;
      }
    )
    (check "disabled REAPER still permits pw-jack for other clients"
      {
        settings = {
          dotfiles.features.dtm.enable = true;
          dotfiles.programs.reaper.enable = false;
        };
      }
      {
        reaper = false;
        reaperJack = false;
      }
    )
    (check "independent REAPER survives disabled DTM without JACK setup"
      { settings.dotfiles.programs.reaper.enable = true; }
      {
        feature = false;
        homeJack = false;
        reaperJack = false;
      }
    )
    (check "embedded Home Manager inherits enabled NixOS JACK" {
      settings.dotfiles.features.dtm.enable = true;
      osConfig.dotfiles.features.dtm = {
        enable = true;
        jack.enable = true;
      };
    } { })
    (check "embedded Home Manager inherits NixOS JACK opt-out"
      {
        settings.dotfiles.features.dtm.enable = true;
        osConfig.dotfiles.features.dtm = {
          enable = true;
          jack.enable = false;
        };
      }
      {
        jack = false;
        homeJack = false;
        reaperJack = false;
      }
    )
    (check "embedded Home Manager inherits disabled NixOS DTM"
      {
        settings.dotfiles.features.dtm.enable = true;
        osConfig.dotfiles.features.dtm = {
          enable = false;
          jack.enable = true;
        };
      }
      {
        jack = false;
        homeJack = false;
        reaperJack = false;
      }
    )
    (check "explicit Home Manager JACK selection overrides the NixOS default" {
      settings.dotfiles.features.dtm = {
        enable = true;
        jack.enable = true;
      };
      osConfig.dotfiles.features.dtm = {
        enable = true;
        jack.enable = false;
      };
    } { })
    (check "custom DTM packages and REAPER libraries are preserved"
      {
        settings = {
          dotfiles.features.dtm = {
            enable = true;
            packages = [ pkgs.hello ];
            linuxPackages = [ pkgs.cowsay ];
          };
          programs.reaper.packages = [ pkgs.libpng ];
        };
      }
      {
        customPackages = [
          pkgs.hello
          pkgs.cowsay
        ];
        customReaperPackages = [ pkgs.libpng ];
      }
    )
  ];
  darwin = evaluate {
    settings = {
      nixpkgs.system = "aarch64-darwin";
      dotfiles.features.dtm.enable = true;
    };
  };
  darwinWithJack = evaluate {
    settings = {
      nixpkgs.system = "aarch64-darwin";
      dotfiles.features.dtm = {
        enable = true;
        jack.enable = true;
      };
    };
  };
in
assert lib.all (result: result) cases;
assert !darwin.dotfiles.features.dtm.jack.enable;
assert darwin.programs.reaper.enable;
assert darwin.programs.reaper.packages == [ ];
assert darwinWithJack.programs.reaper.packages == [ ];
assert lib.all (package: lib.getName package != "pipewire") darwinWithJack.home.packages;
pkgs.runCommandLocal "dtm-home-eval-test" { } ''touch "$out"''
