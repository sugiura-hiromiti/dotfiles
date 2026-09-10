{
  lib,
  pkgs,
  disko,
  ...
}:
let
  system = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      disko.nixosModules.disko
      ../../modules/nixos/features/storage
      {
        dotfiles = {
          features = {
            storage = {
              partitionLabel = "test-system";
              provisioning = {
                enable = true;
                disk = "/dev/test-disk";
              };
            };
          };
        };
      }
    ];
  };
  disk = system.config.disko.devices.disk.main;
  systemPartition = disk.content.partitions.system;
  subvolumes = systemPartition.content.subvolumes;
in
assert disk.device == "/dev/test-disk";
assert disk.content.type == "gpt";

assert systemPartition.name == "test-system";
assert systemPartition.content.type == "btrfs";

assert subvolumes ? "@root";
assert subvolumes ? "@nix";
assert subvolumes ? "@persist";

pkgs.runCommandLocal "storage-providioning-eval-test" { } ''touch "$out"''
