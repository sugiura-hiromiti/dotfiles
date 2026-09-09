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
          mounts = [
            {
              what = cfg.device;
              where = mountPoint;
              type = "btrfs";
              options = "subvolid=5";
            }
          ];
          services = {
            ephemeral-root-reset = {
              requires = [ mountUnit ];
              after = [ mountUnit ];
              requiredBy = [ "sysroot.mount" ];
              before = [ "sysroot.mount" ];
              unitConfig = {
                DefaultDependencies = false;
              };
              serviceConfig = {
                ExecStart = "${btrfs} subvolume show ${mountPoint}/@root";
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
