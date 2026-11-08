{
  lib,
  pkgs,
  preservation,
}:
let
  primary = "game-test";
  evaluate =
    settings:
    (lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      specialArgs.accounts.primary = primary;
      modules = [
        ../../modules/nixos/features/game.nix
        ../../modules/nixos/programs/prismlauncher
        ../../modules/nixos/features/impermanence/preservation.nix
        preservation.nixosModules.default
        {
          boot.isContainer = true;
          system.stateVersion = "26.05";
          users.users.${primary} = {
            isNormalUser = true;
            home = "/home/game-test";
          };
        }
        settings
      ];
    }).config;

  check =
    name: settings: expected:
    let
      config = evaluate settings;
      directories = config.preservation.preserveAt."/persist".users.${primary}.directories or [ ];
      prismDirectory = "${config.users.users.${primary}.home}/.local/share/PrismLauncher";
    in
    assert lib.assertMsg (
      config.dotfiles.features.game.enable == expected.game
    ) "${name}: unexpected game feature activation";
    assert lib.assertMsg (
      config.dotfiles.features.game.prismlauncher.enable == expected.child
    ) "${name}: unexpected PrismLauncher child option";
    assert lib.assertMsg (
      config.dotfiles.programs.prismlauncher.preserveData == expected.program
    ) "${name}: unexpected PrismLauncher preservation request";
    assert lib.assertMsg (
      config.dotfiles.features.preservation.enable == expected.preservation
      && config.preservation.enable == expected.preservation
    ) "${name}: unexpected preservation infrastructure activation";
    assert lib.assertMsg (
      lib.any (directory: directory.directory == prismDirectory) directories == expected.directory
    ) "${name}: unexpected PrismLauncher preservation directory";
    true;

  cases = [
    (check "omitted feature defaults to disabled" { } {
      game = false;
      child = true;
      program = false;
      preservation = false;
      directory = false;
    })
    (check "disabled feature leaves preservation request disabled"
      { dotfiles.features.game.enable = false; }
      {
        game = false;
        child = true;
        program = false;
        preservation = false;
        directory = false;
      }
    )
    (check "enabled feature requests preservation by default" { dotfiles.features.game.enable = true; }
      {
        game = true;
        child = true;
        program = true;
        preservation = false;
        directory = false;
      }
    )
    (check "child opt-out leaves preservation request disabled"
      {
        dotfiles.features = {
          game = {
            enable = true;
            prismlauncher.enable = false;
          };
          preservation.enable = true;
        };
      }
      {
        game = true;
        child = false;
        program = false;
        preservation = true;
        directory = false;
      }
    )
    (check "independent Program request survives disabled feature"
      {
        dotfiles.features = {
          game.enable = false;
          preservation.enable = true;
        };
        dotfiles.programs.prismlauncher.preserveData = true;
      }
      {
        game = false;
        child = true;
        program = true;
        preservation = true;
        directory = true;
      }
    )
    (check "explicit Program disable overrides enabled feature"
      {
        dotfiles.features = {
          game.enable = true;
          preservation.enable = true;
        };
        dotfiles.programs.prismlauncher.preserveData = false;
      }
      {
        game = true;
        child = true;
        program = false;
        preservation = true;
        directory = false;
      }
    )
    (check "enabled feature respects disabled preservation infrastructure"
      {
        dotfiles.features = {
          game.enable = true;
          preservation.enable = false;
        };
      }
      {
        game = true;
        child = true;
        program = true;
        preservation = false;
        directory = false;
      }
    )
    (check "enabled infrastructure preserves requested PrismLauncher directory"
      {
        dotfiles.features = {
          game.enable = true;
          preservation.enable = true;
        };
      }
      {
        game = true;
        child = true;
        program = true;
        preservation = true;
        directory = true;
      }
    )
    (check "variant enables feature by default"
      { imports = [ ../../profiles/variants/game/nixos.nix ]; }
      {
        game = true;
        child = true;
        program = true;
        preservation = false;
        directory = false;
      }
    )
    (check "explicit disable overrides variant default"
      {
        imports = [ ../../profiles/variants/game/nixos.nix ];
        dotfiles.features.game.enable = false;
      }
      {
        game = false;
        child = true;
        program = false;
        preservation = false;
        directory = false;
      }
    )
  ];
in
assert lib.all (result: result) cases;
pkgs.runCommandLocal "game-nixos-eval-test" { } ''touch "$out"''
