{
  lib,
  config,
  utils,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.ephemeralRoot;
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
          extraBin = {
            btrfs = lib.getExe' pkgs.btrfs-progs "btrfs";
          };
          services = {
            ephemeral-root-reset =
              let
                deviceUnit = "${utils.escapeSystemdPath cfg.device}.device";
              in
              {
                requires = [ deviceUnit ];
                after = [ deviceUnit ];
                requiredBy = [ "sysroot.mount" ];
                before = [ "sysroot.mount" ];
                unitConfig = {
                  DefaultDependencies = false;
                };
                serviceConfig = {
                  Type = "oneshot";
                };
                script = ''
                  mkdir -p /run/ephemeral-root
                  mount -t btrfs -o subvolid=5 ${cfg.device} /run/ephemeral-root
                  btrfs subvolume show /run/ephemeral-root/@root
                  umount /run/ephemeral-root
                  echo ran > /run/ephemeral-root-reset-ran
                '';
              };
          };
        };
      };
    };
  };
}
