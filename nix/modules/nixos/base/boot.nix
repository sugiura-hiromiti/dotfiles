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
  options.dotfiles.nixos.boot = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to configure baseline boot, kernel, and storage behavior.";
    };

    performanceTuning = {
      enable = lib.mkEnableOption "performance-oriented boot and kernel tuning";

      sysctl = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {
          "net.ipv4.ip_unprivileged_port_start" = 0;
          "vm.swappiness" = 10;
          "vm.vfs_cache_pressure" = 50;
          "vm.dirty_background_ratio" = 5;
          "vm.dirty_ratio" = 20;
          "kernel.sched_autogroup_enabled" = 0;
          "fs.inotify.max_user_watches" = 524288;
          "fs.inotify.max_user_instances" = 8192;
        };
        description = "Kernel sysctl values used when performance tuning is enabled.";
      };

      kernelParams = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "numa_balancing=disable"
          "mitigations=off"
          "transparent_hugepage=never"
        ];
        description = "Kernel parameters used when performance tuning is enabled.";
      };

      cpuFreqGovernor = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "performance";
        description = "CPU frequency governor used when performance tuning is enabled. Null leaves it unset.";
      };

      nvmeScheduler = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "none";
        description = "NVMe scheduler used when performance tuning is enabled. Null leaves udev rules unset.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        fileSystems."/" = {
          options = [ "noatime" ];
        };

        boot = {
          loader = {
            systemd-boot.enable = lib.mkDefault true;
            efi.canTouchEfiVariables = lib.mkDefault false;
          };

          kernelPackages = lib.mkDefault pkgs.linuxPackages;
        };

        zramSwap.enable = lib.mkDefault true;
      }

      (lib.mkIf cfg.performanceTuning.enable (
        lib.mkMerge [
          {
            boot = {
              kernel.sysctl = cfg.performanceTuning.sysctl;
              kernelParams = cfg.performanceTuning.kernelParams;
            };
          }

          (lib.mkIf (cfg.performanceTuning.cpuFreqGovernor != null) {
            powerManagement.cpuFreqGovernor = lib.mkDefault cfg.performanceTuning.cpuFreqGovernor;
          })

          (lib.mkIf (cfg.performanceTuning.nvmeScheduler != null) {
            services.udev.extraRules = ''
              ACTION=="add|change", KERNEL=="nvme*", ATTR{queue/scheduler}="${cfg.performanceTuning.nvmeScheduler}"
            '';
          })
        ]
      ))
    ]
  );
}
