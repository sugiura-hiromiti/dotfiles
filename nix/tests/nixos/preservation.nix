{ pkgs, preservation }:
pkgs.testers.runNixOSTest {
  name = "dotfiles.preservation";
  testScript = ''
    machine.start(allow_reboot=True)
    machine.wait_for_unit("default.target")

    with subtest("persistent storage is mounted"):
        machine.succeed("mountpoint /persist")
        machine.succeed("mountpoint /var/lib/tailscale")
        machine.succeed("mountpoint /home/a/dotfiles")

    with subtest("/var/lib/nixos is managed by Preservation"):
        machine.succeed("mountpoint /var/lib/nixos")

    with subtest("write persistent and ephemeral state"):
        machine.succeed(
            "echo preserved > /var/lib/nixos/ptest0"
        )
        machine.succeed(
            "grep -q preserved /persist/var/lib/nixos/ptest0"
        )

        machine.succeed(
            "echo ephemeral > /home/a/ephemeral-test"
        )

    with subtest("services are healthy before reboot"):
        machine.wait_for_unit("sshd.service")
        machine.wait_for_unit("NetworkManager.service")

    machine_id = machine.succeed("cat /etc/machine-id").strip()
    ssh_host_identity = machine.succeed(
        "ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key"
    ).strip()

    with subtest("Networkmanager owns persistent state"):
        machine.succeed(
            "nmcli connection add "
            "type dummy "
            "ifname ptest0 "
            "con-name ptest0"
    )

    nm_uuid = machine.succeed("nmcli -g connection.uuid connection show ptest0").strip()

    with subtest("user repository state is preserved"):
        machine.succeed("echo working-copy > /home/a/dotfiles/test")

        machine.reboot()
        machine.wait_for_unit("default.target")

        machine.succeed(
            "grep -q preserved /var/lib/nixos/ptest0"
        )
        machine.succeed(
            "grep -q preserved /persist/var/lib/nixos/ptest0"
        )

        machine.fail(
            "test -e /home/a/ephemeral-test"
        )

        machine.succeed("grep -q working-copy /home/a/dotfiles/test")

    with subtest("Tailscale state directory is persistent"):
        machine.succeed(
            "echo tailscale-preserved "
            "> /var/lib/tailscale/preservation-test"
        )

        machine.succeed(
            "grep -q tailscale-preserved "
            "/persist/var/lib/tailscale/preservation-test"
        )

    with subtest("services recover after reboot"):
        machine.wait_for_unit("sshd.service")
        machine.wait_for_unit("tailscaled.service")
        machine.wait_for_unit("NetworkManager.service")

    with subtest("machine identity survives reboot"):
        assert machine.succeed(
            "cat /etc/machine-id"
        ).strip() == machine_id

    with subtest("SSH host identity survives reboot"):
        assert machine.succeed(
            "ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key"
        ).strip() == ssh_host_identity

    with subtest("NetworkManager state survives reboot"):
        assert machine.succeed(
            "nmcli -g connection.uuid connection show ptest0"
        ).strip() == nm_uuid

    with subtest("Tailscale daemon is usable before reboot"):
        machine.succeed(
            "tailscale status --json --peers=false >/dev/null"
        )

    with subtest("Tailscale recovers after reboot"):
        machine.succeed(
            "test -S /run/tailscale/tailscaled.sock"
        )

        machine.succeed(
            "tailscale status --json --peers=false >/dev/null"
        )

        machine.succeed(
            "grep -q tailscale-preserved "
            "/var/lib/tailscale/preservation-test"
        )

    machine.shutdown()
  '';
  nodes = {
    machine = { lib, ... }: {
      services = {
        tailscale = {
          enable = true;
          disableUpstreamLogging = true;
        };
        openssh = {
          enable = true;
        };
      };
      _module = {
        args = {
          accounts = {
            primary = "a";
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
      imports = [
        preservation.nixosModules.default
        ../../modules/nixos/base/boot.nix
        ../../modules/nixos/features/impermanence/preservation.nix
      ];
      dotfiles = {
        features = {
          preservation = {
            enable = true;
          };
        };
      };
      networking = {
        networkmanager = {
          enable = true;
        };
        useNetworkd = true;
      };
      virtualisation = {
        memorySize = 1024;
        emptyDiskImages = [ 64 ];

        fileSystems = {
          "/persist" = {
            device = "/dev/vdb";
            fsType = "ext4";
            neededForBoot = true;
            autoFormat = true;
          };
          "/" = {
            device = lib.mkForce "none";
            # TODO: i want to change this to something like btrfs bacause i wouldn't use tmpfs for root impermanency
            fsType = lib.mkForce "tmpfs";
            options = lib.mkForce [ "mode=0755" ];
            neededForBoot = true;
          };
        };
      };
    };
  };
}
