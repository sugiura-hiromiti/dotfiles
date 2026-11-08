{
  lib,
  pkgs,
  home-manager,
}:
let
  evaluate =
    settings:
    (home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ../../modules/home/features/game.nix
        ../../modules/home/programs/prismlauncher
        {
          home = {
            username = "game-test";
            homeDirectory = "/home/game-test";
            stateVersion = "26.05";
          };
        }
        settings
      ];
    }).config;

  check =
    name: settings: expected:
    let
      config = evaluate settings;
    in
    assert lib.assertMsg (
      config.dotfiles.features.game.enable == expected.game
    ) "${name}: unexpected game feature activation";
    assert lib.assertMsg (
      config.dotfiles.features.game.prismlauncher.enable == expected.child
    ) "${name}: unexpected PrismLauncher child option";
    assert lib.assertMsg (
      config.dotfiles.programs.prismlauncher.enable == expected.program
    ) "${name}: unexpected repository PrismLauncher activation";
    assert lib.assertMsg (
      config.programs.prismlauncher.enable == expected.program
    ) "${name}: unexpected Home Manager PrismLauncher activation";
    true;

  cases = [
    (check "omitted feature defaults to disabled" { } {
      game = false;
      child = true;
      program = false;
    })
    (check "disabled feature leaves Program disabled" { dotfiles.features.game.enable = false; } {
      game = false;
      child = true;
      program = false;
    })
    (check "enabled feature enables Program by default" { dotfiles.features.game.enable = true; } {
      game = true;
      child = true;
      program = true;
    })
    (check "child opt-out leaves Program disabled"
      {
        dotfiles.features.game = {
          enable = true;
          prismlauncher.enable = false;
        };
      }
      {
        game = true;
        child = false;
        program = false;
      }
    )
    (check "independent Program activation survives disabled feature"
      {
        dotfiles.features.game.enable = false;
        dotfiles.programs.prismlauncher.enable = true;
      }
      {
        game = false;
        child = true;
        program = true;
      }
    )
    (check "explicit Program disable overrides enabled feature"
      {
        dotfiles.features.game.enable = true;
        dotfiles.programs.prismlauncher.enable = false;
      }
      {
        game = true;
        child = true;
        program = false;
      }
    )
    (check "variant enables feature by default" { imports = [ ../../profiles/variants/game/home.nix ]; }
      {
        game = true;
        child = true;
        program = true;
      }
    )
    (check "explicit disable overrides variant default"
      {
        imports = [ ../../profiles/variants/game/home.nix ];
        dotfiles.features.game.enable = false;
      }
      {
        game = false;
        child = true;
        program = false;
      }
    )
  ];
in
assert lib.all (result: result) cases;
pkgs.runCommandLocal "game-home-eval-test" { } ''touch "$out"''
