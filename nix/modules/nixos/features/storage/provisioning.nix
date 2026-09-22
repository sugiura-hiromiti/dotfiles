{ disko }:
let
  layout = import ./layout.nix;
in
{
  imports = [ disko.nixosModules.disko ];
  disko.enableConfig = true;
  disko.devices.disk.main = {
    type = "disk";
    device = layout.installerDisk;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        system = {
          label = layout.partitionLabel;
          size = "100%";
          content = {
            type = "btrfs";
            subvolumes = {
              ${layout.subvolumes.root}.mountpoint = "/";
              ${layout.subvolumes.nix}.mountpoint = "/nix";
              ${layout.subvolumes.persist}.mountpoint = "/persist";
            };
          };
        };
      };
    };
  };
}
