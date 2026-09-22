{
  preservation,
  lib,
  disko,
  pkgs,
  home-manager,
  ...
}:
let
  targetSystem = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    specialArgs = {
      accounts = {
        primary = "a";
      };
    };

    modules = [
      (import ../../modules/nixos/features/storage/provisioning.nix { inherit disko; })
      ../../modules/nixos/features/impermanence
      preservation.nixosModules.default
      home-manager.nixosModules.home-manager

      ({ modulesPath, ... }: {
        imports = [ (modulesPath + "/testing/test-instrumentation.nix") ];
      })

      {
        services.openssh.enable = true;
        services.tailscale = {
          enable = true;
          disableUpstreamLogging = true;
        };
        networking.networkmanager.enable = true;
        home-manager = {
          users = {
            a = {
              home = {
                stateVersion = "26.05";
                file = {
                  ".config/impermanence-reconstruction-probe" = {
                    text = "reconstructed\n";
                  };
                };
              };
            };
          };
        };
        users = {
          users = {
            a = {
              isNormalUser = true;
              uid = 1000;
            };
          };
        };
        boot = {
          loader = {
            systemd-boot = {
              enable = true;
            };
            efi.canTouchEfiVariables = false;
            grub = {
              enable = false;
            };
          };
        };
        dotfiles = {
          features = {
            preservation = {
              enable = true;
            };
            impermanence = {
              enable = true;
            };

          };
        };
      }
    ];
  };
  diskoScript = targetSystem.config.system.build.diskoScript;
  targetTopLevel = targetSystem.config.system.build.toplevel;
in
pkgs.testers.runNixOSTest {
  name = "dotfiles.impermanence-vm";
  nodes = {
    target = {
      virtualisation = {
        fileSystems = {
          "/" = {
            device = "/dev/disk/by-partlabel/unused-test-root";
            fsType = "ext4";
          };
        };
        diskImage = "./target.qcow2";
        useBootLoader = true;
        useEFIBoot = true;
        useDefaultFilesystems = false;
        efi = {
          keepVariables = false;
        };
      };
    };
    installer = {
      virtualisation = {
        diskImage = "./target.qcow2";
        diskSize = 4096;
        additionalPaths = [ targetTopLevel ];
        rootDevice = "/dev/vdb";
        emptyDiskImages = [ 1024 ];
        fileSystems = {
          "/" = {
            autoFormat = true;
          };
        };
      };
    };
  };
  testScript = ''
    with subtest("provision and install impermanent system"):
        installer.start()
        installer.wait_for_unit("multi-user.target")
        installer.succeed("test -b /dev/vda")
        installer.succeed("ln -s /dev/vda /dev/dotfiles-install-target")
        installer.succeed("${diskoScript}")

        installer.succeed("test -b /dev/disk/by-partlabel/dotfiles-system")

        installer.succeed("mountpoint -q /mnt")
        installer.succeed("mountpoint -q /mnt/nix")
        installer.succeed("mountpoint -q /mnt/persist")
        installer.succeed("mountpoint -q /mnt/boot")

        installer.succeed(
            "${pkgs.nixos-install-tools}/bin/nixos-install "
            "--root /mnt "
            "--system ${targetTopLevel} "
            "--no-channel-copy "
            "--no-root-password "
        )

        installer.succeed("test -L /mnt/nix/var/nix/profiles/system")
        installer.succeed("test -e /mnt/etc/NIXOS")
        installer.succeed("test -e /mnt/boot/loader/loader.conf")
        installer.succeed(
            "test -e /mnt/boot/EFI/BOOT/"
            "BOOT${lib.toUpper pkgs.stdenv.hostPlatform.efiArch}.EFI"
        )

        installer.succeed("umount -R /mnt")
        installer.succeed("sync")
        installer.shutdown()

    with subtest("boot installed impermanent system"):
        target.state_dir = installer.state_dir
        target.start(allow_reboot=True)
        target.wait_for_unit("multi-user.target")
        target.wait_for_unit("home-manager-a.service")
        target.succeed("grep -qx reconstructed " "/home/a/.config/impermanence-reconstruction-probe")

        target.succeed("mountpoint -q /var/lib/nixos")
        target.succeed('test "$(findmnt -n -o FSTYPE /)" = btrfs')
        target.succeed('test "$(findmnt -n -o FSROOT /)" = /@root')
        target.succeed('test "$(findmnt -n -o FSROOT /nix)" = /@nix')
        target.succeed('test "$(findmnt -n -o FSROOT /persist)" = /@persist')

    with subtest("persistent services before reboot"):
        target.wait_for_unit("sshd.service")
        target.wait_for_unit("tailscaled.service")
        target.wait_for_unit("NetworkManager.service")
        machine_id = target.succeed("cat /etc/machine-id").strip()
        ssh_key = target.succeed("ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key").strip()
        target.succeed("nmcli connection add type dummy ifname ptest0 con-name ptest0")
        nm_uuid = target.succeed("nmcli -g connection.uuid connection show ptest0").strip()
        target.succeed("tailscale status --json --peers=false >/dev/null")
        target.succeed("echo tailscale-preserved > /var/lib/tailscale/preservation-test")

    with subtest("create disposable and persistent state"):
        target.succeed("mountpoint -q /home/a/dotfiles")
        target.succeed("su - a -c 'echo repository > ~/dotfiles/probe'")
        target.succeed("echo nix-persistent > /nix/impermanence-nix-marker")
        target.succeed("echo disposable > /impermanence-root-marker")
        target.succeed(
            "echo persistent > /persist/impermanence-persist-marker"
        )
        target.succeed(
            "echo disposable > "
            "/home/a/.config/impermanence-disposable-marker"
        )

        target.succeed(
            "echo preserved > /var/lib/nixos/impermanence-preservation-marker"
        )
        target.succeed(
            "grep -qx preserved "
            "/persist/var/lib/nixos/impermanence-preservation-marker"
        )

    with subtest("reboot impermanent system"):
        target.succeed("sync")
        target.reboot()
        target.wait_for_unit("multi-user.target")
        target.wait_for_unit("home-manager-a.service")

    with subtest("persistent services after reboot"):
        target.wait_for_unit("sshd.service")
        target.wait_for_unit("tailscaled.service")
        target.wait_for_unit("NetworkManager.service")
        assert target.succeed("cat /etc/machine-id").strip() == machine_id
        assert target.succeed("ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key").strip() == ssh_key
        assert target.succeed("nmcli -g connection.uuid connection show ptest0").strip() == nm_uuid
        target.succeed("tailscale status --json --peers=false >/dev/null")
        target.succeed("grep -qx tailscale-preserved /var/lib/tailscale/preservation-test")
        target.succeed("grep -qx tailscale-preserved /persist/var/lib/tailscale/preservation-test")

    with subtest("verify impermanence contract"):
        target.succeed("grep -qx repository /home/a/dotfiles/probe")
        target.succeed("grep -qx repository /persist/home/a/dotfiles/probe")
        target.succeed("grep -qx nix-persistent /nix/impermanence-nix-marker")
        target.succeed("su - a -c 'echo writable >> ~/dotfiles/probe'")
        target.succeed("test ! -e /impermanence-root-marker")

        target.succeed(
            'test "$(cat /persist/impermanence-persist-marker)" = persistent'
        )

        target.succeed(
            "grep -qx preserved "
            "/var/lib/nixos/impermanence-preservation-marker"
        )
        target.succeed(
            "grep -qx preserved "
            "/persist/var/lib/nixos/impermanence-preservation-marker"
        )

        target.succeed(
            "test ! -e /home/a/.config/impermanence-disposable-marker"
        )
        target.succeed(
            "grep -qx reconstructed "
            "/home/a/.config/impermanence-reconstruction-probe"
        )
  '';
}
