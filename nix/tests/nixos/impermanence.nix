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
  fs = system.config.fileSystems;
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
pkgs.runCommandLocal "impermanence-eval-test" { } ''touch "$out"''
