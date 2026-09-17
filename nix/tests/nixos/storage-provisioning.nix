{
  lib,
  pkgs,
  disko,
  ...
}:
let
  filesystemUuid = "11111111-2222-4333-8444-555555555555";
  system = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      (import ../../modules/nixos/features/storage/provisioning.nix { inherit disko; })
      {
        dotfiles = {
          features = {
            storage = {
              inherit filesystemUuid;
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
  esp = disk.content.partitions.ESP;
in
assert disk.device == "/dev/test-disk";
assert disk.content.type == "gpt";

assert esp.type == "EF00";
assert esp.content.type == "filesystem";
assert esp.content.format == "vfat";
assert esp.content.mountpoint == "/boot";

assert systemPartition.label == "test-system";
assert systemPartition.device == "/dev/disk/by-partlabel/test-system";
assert systemPartition.content.type == "btrfs";

assert subvolumes ? "@root";
assert subvolumes ? "@nix";
assert subvolumes ? "@persist";

assert system.config.disko.enableConfig;

assert system.config.dotfiles.features.storage.device == "/dev/disk/by-uuid/${filesystemUuid}";

pkgs.runCommandLocal "storage-provisioning-eval-test" { } ''touch "$out"''
