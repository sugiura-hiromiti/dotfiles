# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  lib,
  pkgs,
  user,
  theme,
  hostName ? null,
  host ? null,
  ...
}:
{
  system = {
    autoUpgrade = {
      enable = true;
      allowReboot = true;
    };
  };
  fileSystems = {
    "/" = {
      options = [ "noatime" ];
    };
  };
  boot = {
    # Bootloader.
    loader = {
      systemd-boot = {
        enable = true;
      };
      efi = {
        canTouchEfiVariables = false;
      };
    };
    # Use latest kernel.
    kernelPackages = pkgs.linuxPackages;
    kernel = {
      sysctl = {
        "net.ipv4.ip_unprivileged_port_start" = 0;
        "vm.swappiness" = 10;
        "vm.vfs_cache_pressure" = 50;
        "vm.dirty_background_ratio" = 5;
        "vm.dirty_ratio" = 20;
        # "vm.max_map_count" = 1048576;
        "kernel.sched_autogroup_enabled" = 0;
        "fs.inotify.max_user_watches" = 524288;
        "fs.inotify.max_user_instances" = 8192;
      };
    };
    kernelParams = [
      "numa_balancing=disable"
      "mitigations=off"
      "transparent_hugepage=never"
    ];
    # binfmt = {
    #   # preferStaticEmulators = true;
    #   emulatedSystems = [ "x86_64-linux" ];
    #   registrations = {
    #     x86_64-linux = {
    #       # preserveArgvZero = false;
    #       fixBinary = true;
    #       # openBinary = true;
    #     };
    #   };
    # };
  };
  hardware = {
    # bluetooth = {
    #   enable = true;
    # settings = {
    #   General = {
    #     ControllerMode = "bredr";
    #   };
    # };
    # };
  };
  powerManagement = {
    cpuFreqGovernor = "performance";
  };

  networking = {
    hostName = lib.mkDefault (
      if hostName != null then
        hostName
      else if host != null then
        host
      else
        "nixos"
    );
    networkmanager = {
      enable = true;
    };
    firewall = {
      allowedTCPPorts = [ 22 ];
    };
  };

  # swapDevices = [
  #   {
  #     device = "/var/lib/swapfile";
  #     size = 16 * 1024;
  #   }
  # ];
  zramSwap = {
    enable = true;
  };
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking

  # Set your time zone.
  time.timeZone = "Asia/Tokyo";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = [ pkgs.fcitx5-skk ];
    };
  };

  fonts = {
    packages = with pkgs; [
      maple-mono.NF-CN
      noto-fonts-color-emoji
    ];
    fontDir = {
      enable = true;
    };
    fontconfig = {
      defaultFonts = {
        serif = [ "Maple Mono NF CN" ];
        sansSerif = [ "Maple Mono NF CN" ];
        monospace = [ "Maple Mono NF CN" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };

  services = {
    greetd = {
      enable = true;
      useTextGreeter = true;
      settings = {
        default_session = {
          command = ''
            ${pkgs.tuigreet}/bin/tuigreet \
            --remember-session \
            --remember \
            --cmd ${pkgs.niri}/bin/niri-session
          '';
          user = "greeter";
        };
      };
    };
    udev = {
      extraRules = ''
        ACTION=="add|change", KERNEL=="nvme*", ATTR{queue/scheduler}="none"
      '';
    };
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
      };
    };
    xserver = {
      enable = false;
    };
    tailscale = {
      enable = true;
    };
    # printing = {
    #   enable = true;
    # };
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = false;
      };
      pulse = {
        enable = true;
      };
      jack = {
        enable = true;
      };
      wireplumber = {
        extraConfig = {
          "50-alsa-config" = {
            "monitor.alsa.rules" = [
              {
                matches = [ { "node.name" = "~alsa_output.*"; } ];
                actions = {
                  update-props = {
                    "api.alsa.period-size" = 2048;
                    "api.alsa.headroom" = 8192;
                  };
                };
              }
            ];
          };
        };
      };
      extraConfig = {
        pipewire = {
          "10-buffer" = {
            "context.properties" = {
              "default.clock.rate" = 48000;
              "default.clock.allowed-rates" = [
                44100
                48000
              ];
              "default.clock.quantum" = 512;
              "default.clock.min-quantum" = 256;
              "default.clock.max-quantum" = 1024;
            };
          };
        };
      };
    };
    # kanata = {
    #   enable = true;
    #   keyboards = {
    #     dflt = {
    #       port = 6666;
    #       configFile = ../../kanata/kanata.scm;
    #       devices = [ "/dev/input/by-id/usb-VMware_VMware_Virtual_USB_Keyboard-event-kbd" ];
    #     };
    #   };
    # };
  };
  security = {
    rtkit = {
      enable = true;
    };
  };
  virtualisation = {
    # docker = {
    #   enable = true;
    #   daemon = {
    #     settings = {
    #       features = {
    #         buildkit = true;
    #       };
    #     };
    #   };
    #   rootless = {
    #     enable = true;
    #     daemon = {
    #       settings = {
    #         features = {
    #           buildkit = true;
    #         };
    #       };
    #     };
    #     setSocketVariable = true;
    #   };
    # };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users = {
  #   users = {
  #     a = {
  #       isNormalUser = true;
  #       description = "a";
  #       extraGroups = [
  #         "networkmanager"
  #         "wheel"
  #         "inputs"
  #       ];
  #       packages = with pkgs; [ ];
  #       shell = pkgs.nushell;
  #       openssh = {
  #         authorizedKeys = {
  #           keys = [
  #             "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8t5TzxjrjRbwyCUZLKrYAK8Yl1g5qmolDF/cHUq0ro android"
  #             "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID/SVDZ/Jc53n3NbfQMadDpq5cmtRvjBzLXrVE8NzW1m ios"
  #           ];
  #         };
  #       };
  #     };
  #   };
  # };

  programs = {
    # nh = {
    #   enable = true;
    #   clean = {
    #     enable = true;
    #     extraArgs = "--optimise";
    #   };
    # };
    # xwayland = {
    #   enable = true;
    # };
    niri = {
      enable = true;
      useNautilus = false;
    };
    nix-ld = {
      enable = true;
    };
  };

  # Enable automatic login for the user.
  # services.getty.autologinUser = "a";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    systemPackages = with pkgs; [
      pipewire
      pipewire.jack
      jack2
      jack-example-tools
      tuigreet
      tailscale
      #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
      #  wget
    ];
  };
  # environment.sessionVariables = {
  #   XDG_CURRENT_DESKTOP = "sway";
  #   XDG_SESSION_DESKTOP = "sway";
  # };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };
  catppuccin = {
    enable = true;
    flavor = if theme == "dark" then "frappe" else "latte";
    fcitx5 = {
      accent = "yellow";
      enableRounded = true;
    };
  };
}
