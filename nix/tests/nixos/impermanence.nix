{ lib, pkgs, ... }:
let
  importWith = subVolNamePrefix: [
    ../../modules/nixos/features/impermanence/impermanence.nix
    {
      dotfiles = {
        features = {
          impermanence = {
            enable = true;
            device = "/dev/test";
            subvolumes = lib.mkIf (subVolNamePrefix != "") {
              root = "@${subVolNamePrefix}root";
              persist = "@${subVolNamePrefix}persist";
              nix = "@${subVolNamePrefix}nix";
            };
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
  customFs = customSystem.config.fileSystems;
  subvolOptions = fs: builtins.filter (option: lib.hasPrefix "subvol=" option) fs.options;
in
assert fs."/".device == "/dev/test";
assert fs."/".fsType == "btrfs";
assert subvolOptions fs."/" == [ "subvol=@root" ];

assert fs."/persist".device == "/dev/test";
assert fs."/persist".fsType == "btrfs";
assert subvolOptions fs."/persist" == [ "subvol=@persist" ];
assert fs."/persist".neededForBoot;

assert fs."/nix".device == "/dev/test";
assert fs."/nix".fsType == "btrfs";
assert subvolOptions fs."/nix" == [ "subvol=@nix" ];
assert fs."/nix".neededForBoot;

assert subvolOptions customFs."/" == [ "subvol=@test-root" ];
assert subvolOptions customFs."/persist" == [ "subvol=@test-persist" ];
assert subvolOptions customFs."/nix" == [ "subvol=@test-nix" ];

assert system.config.dotfiles.features.ephemeralRoot.subvolume == "@root";
assert customSystem.config.dotfiles.features.ephemeralRoot.subvolume == "@test-root";

assert system.config.dotfiles.features.ephemeralRoot.enable;
assert system.config.dotfiles.features.ephemeralRoot.device == "/dev/test";

assert customSystem.config.dotfiles.features.ephemeralRoot.enable;
assert customSystem.config.dotfiles.features.ephemeralRoot.device == "/dev/test";

pkgs.runCommandLocal "impermanence-eval-test" { } ''touch "$out"''
