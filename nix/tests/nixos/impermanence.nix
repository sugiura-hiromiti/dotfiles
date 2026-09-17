{
  lib,
  pkgs,
  ...
}:
let
  filesystemUuid = "11111111-2222-4333-8444-555555555555";
  importWith = subVolNamePrefix: [
    ../../modules/nixos/features/impermanence/impermanence.nix
    {
      dotfiles = {
        features = {
          storage = {
            inherit filesystemUuid;
            partitionLabel = "test";
            provisioning = {
              disk = "/dev/test-disk";
            };
            subvolumes = lib.mkIf (subVolNamePrefix != "") {
              root = "@${subVolNamePrefix}root";
              persist = "@${subVolNamePrefix}persist";
              nix = "@${subVolNamePrefix}nix";
            };
          };
          impermanence = {
            enable = true;
          };
        };
      };
    }
  ];
  system = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = importWith "";
  };
  fs = system.config.fileSystems;
  customSystem = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = importWith "test-";
  };
in
assert fs."/persist".neededForBoot;
assert fs."/nix".neededForBoot;

assert !system.config.dotfiles.features.storage.provisioning.enable;

assert
  system.config.dotfiles.features.ephemeralRoot.subvolume
  == system.config.dotfiles.features.storage.subvolumes.root;
assert
  customSystem.config.dotfiles.features.ephemeralRoot.subvolume
  == customSystem.config.dotfiles.features.storage.subvolumes.root;

assert system.config.dotfiles.features.ephemeralRoot.enable;
assert
  system.config.dotfiles.features.ephemeralRoot.device
  == system.config.dotfiles.features.storage.device;

assert customSystem.config.dotfiles.features.ephemeralRoot.enable;
assert
  customSystem.config.dotfiles.features.ephemeralRoot.device
  == customSystem.config.dotfiles.features.storage.device;

pkgs.runCommandLocal "impermanence-eval-test" { } ''touch "$out"''
