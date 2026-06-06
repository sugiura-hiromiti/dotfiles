{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.nixos.boot;
in
{
  options.dotfiles.nixos.boot.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure baseline boot, kernel, and storage behavior.";
  };

  config = lib.mkIf cfg.enable {
    fileSystems."/" = {
      options = [ "noatime" ];
    };

    boot = {
      loader = {
        systemd-boot.enable = lib.mkDefault true;
        efi.canTouchEfiVariables = lib.mkDefault false;
      };

      kernelPackages = lib.mkDefault pkgs.linuxPackages;

      kernel.sysctl = {
        "net.ipv4.ip_unprivileged_port_start" = 0;
        "vm.swappiness" = 10;
        "vm.vfs_cache_pressure" = 50;
        "vm.dirty_background_ratio" = 5;
        "vm.dirty_ratio" = 20;
        "kernel.sched_autogroup_enabled" = 0;
        "fs.inotify.max_user_watches" = 524288;
        "fs.inotify.max_user_instances" = 8192;
      };

      kernelParams = [
        "numa_balancing=disable"
        "mitigations=off"
        "transparent_hugepage=never"
      ];
    };

    powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

    services.udev.extraRules = ''
      ACTION=="add|change", KERNEL=="nvme*", ATTR{queue/scheduler}="none"
    '';

    zramSwap.enable = lib.mkDefault true;
  };
}
