{
  lib,
  config,
  utils,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.ephemeralRoot;
  btrfs = lib.getExe' pkgs.btrfs-progs "btrfs";
  mountPoint = "/run/ephemeral-root";
  mountUnit = "${utils.escapeSystemdPath mountPoint}.mount";
  mountedRoot = "${mountPoint}/${cfg.subvolume}";
in
{
  options = {
    dotfiles = {
      features = {
        ephemeralRoot = {
          device = lib.mkOption {
            type = lib.types.str;
            description = "btrfs device containing the ephemeral @root subvolume";
          };
          subvolume = lib.mkOption {
            type = lib.types.str;
          };
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "whether to enable ephemeral root for impermanent system";
          };
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    boot = {
      initrd = {
        systemd = {
          enable = true;
          mounts = [
            {
              what = cfg.device;
              where = mountPoint;
              type = "btrfs";
              options = "subvolid=5";
            }
          ];
          services =
            let
              deleteServiceName = "ephemeral-root-delete.service";
            in
            {
              ephemeral-root-create = {
                requires = [
                  mountUnit
                  deleteServiceName
                ];
                after = [
                  mountUnit
                  deleteServiceName
                ];
                requiredBy = [ "sysroot.mount" ];
                before = [ "sysroot.mount" ];
                unitConfig = {
                  DefaultDependencies = false;
                };
                serviceConfig = {
                  Type = "oneshot";
                  ExecStart = "${btrfs} subvolume create ${mountedRoot}";
                  ExecStartPost = "${lib.getExe' pkgs.coreutils "touch"} ${mountPoint}-reset-ran";
                };
              };
              ephemeral-root-delete = {
                requires = [ mountUnit ];
                after = [ mountUnit ];
                unitConfig = {
                  DefaultDependencies = false;
                  ConditionPathExists = mountedRoot;
                };
                serviceConfig = {
                  ExecStart = "${btrfs} subvolume delete --recursive --commit-after ${mountedRoot}";
                  ExecStartPost = "${lib.getExe' pkgs.coreutils "touch"} ${mountPoint}-reset-ran";
                  Type = "oneshot";
                };
              };
            };
        };
      };
    };
  };
}
