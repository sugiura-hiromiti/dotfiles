{
  lib,
  config,
  pkgs,
  ...
}:
let
  layout = import ../storage/layout.nix;
  mountPoint = "/run/impermanence-root";
  root = "${mountPoint}/${layout.subvolumes.root}";
  selectRootDevice = pkgs.writeShellScriptBin "impermanence-root-device" (
    builtins.readFile ./root-device.sh
  );
in
{
  options.dotfiles.features.impermanence.enable = lib.mkEnableOption "ephemeral Btrfs root";
  config = lib.mkIf config.dotfiles.features.impermanence.enable {
    fileSystems."/nix".neededForBoot = true;
    fileSystems."/persist".neededForBoot = true;
    boot.initrd = {
      supportedFilesystems = [ "btrfs" ];
      systemd = {
        enable = true;
        additionalUpstreamUnits = [ "systemd-udev-settle.service" ];
        services.impermanence-reset = {
          requires = [ "systemd-udev-settle.service" ];
          after = [ "systemd-udev-settle.service" ];
          requiredBy = [ "sysroot.mount" ];
          before = [ "sysroot.mount" ];
          unitConfig.DefaultDependencies = false;
          path = [
            selectRootDevice
            pkgs.btrfs-progs
            pkgs.util-linux
            pkgs.coreutils
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            set -euo pipefail
            device=$(impermanence-root-device ${lib.escapeShellArg layout.partitionLabel})
            mkdir -p ${mountPoint}
            mount -t btrfs -o subvolid=5 "$device" ${mountPoint}
            trap 'umount ${mountPoint}' EXIT
            if [ -e ${root} ]; then
              btrfs subvolume delete --recursive --commit-after ${root}
            fi
            btrfs subvolume create ${root}
          '';
        };
      };
    };
  };
}
