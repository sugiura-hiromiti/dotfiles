{
  lib,
  pkgs,
  disko,
  ...
}:
let
  system = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [ (import ../../modules/nixos/features/storage/provisioning.nix { inherit disko; }) ];
  };
  disk = system.config.disko.devices.disk.main;
  partition = disk.content.partitions.system;
  fs = system.config.fileSystems;
in
assert disk.device == "/dev/dotfiles-install-target";
assert disk.content.type == "gpt";
assert disk.content.partitions.ESP.type == "EF00";
assert disk.content.partitions.ESP.content.mountpoint == "/boot";
assert partition.label == "dotfiles-system";
assert partition.content.type == "btrfs";
assert fs."/".device == "/dev/disk/by-partlabel/dotfiles-system";
assert builtins.elem "subvol=@root" fs."/".options;
assert builtins.elem "subvol=@nix" fs."/nix".options;
assert builtins.elem "subvol=@persist" fs."/persist".options;
pkgs.runCommandLocal "storage-provisioning-eval-test" { } ''touch "$out"''
