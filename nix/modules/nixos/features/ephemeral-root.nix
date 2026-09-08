{
  lib,
  config,
  utils,
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
                script = "echo ran > /run/ephemeral-root-reset-ran";
              };
          };
        };
      };
    };
  };
}
