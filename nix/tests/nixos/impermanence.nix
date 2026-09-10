{ lib, pkgs, ... }:
let
  system = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      ../../modules/nixos/features/impermanence/impermanence.nix
      {
        dotfiles = {
          features = {
            impermanence = {
              enable = true;
              device = "/dev/test";
            };
          };
        };
      }
    ];
  };
  fs = system.config.fileSystem;
in
assert fs."/".device == "/dev/test";
assert fs."/".fsType == "btrfs";
assert fs."/".options == [ "subvol=@root" ];

assert fs."/persist".device == "/dev/test";
assert fs."/persist".fsType == "btrfs";
assert fs."/persist".options == [ "subvol=@persist" ];
assert fs."/persist".neededForBoot;

assert fs."/nix".device == "/dev/test";
assert fs."/nix".fsType == "btrfs";
assert fs."/nix".options == [ "subvol=@nix" ];
assert fs."/nix".neededForBoot;
pkgs.runCommandLocal "impermanence-eval-test" { } ''touch "$out"''
