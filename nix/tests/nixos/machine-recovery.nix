{
  pkgs,
  recoveryTarget,
  nixosModulesFor,
  systemSpecialArgs,
}:
pkgs.testers.runNixOSTest {
  name = "dotfiles.machine-recovery";
  node = {
    pkgsReadOnly = false;
    specialArgs = systemSpecialArgs recoveryTarget.config;
  };
  nodes = {
    nixos = {
      imports = nixosModulesFor recoveryTarget.config;
      environment = {
        systemPackages = [ pkgs.btrfs-progs ];
      };
      boot = {
        loader = {
          systemd-boot = {
            enable = true;
          };
          efi = {
            canTouchEfiVariables = true;
          };
        };
      };
      virtualisation = {
        emptyDiskImages = [ 512 ];
        useBootLoader = true;
        useEFIBoot = true;
      };
      specialisation = {
        machine-recovery = {
          configuration = {
            virtualisation = {
              rootDevice = "/dev/vdb";
            };
            fileSystems = pkgs.lib.mkVMOverride {
              "/nix" = {
                device = "/dev/vdb";
                fsType = "btrfs";
                options = [ "subvol=@nix" ];
                neededForBoot = true;
              };
              "/" = {
                fsType = pkgs.lib.mkForce "btrfs";
                options = [ "subvol=@root" ];
              };
              "/persist" = {
                device = "/dev/vdb";
                fsType = "btrfs";
                options = [ "subvol=@persist" ];
                neededForBoot = true;
              };
            };
            dotfiles = {
              features = {
                ephemeralRoot = {
                  enable = true;
                  device = "/dev/vdb";
                };
                preservation = {
                  enable = true;
                };
              };
            };
          };
        };
      };
    };
  };
  testScript =
    { nodes, ... }:
    let
      bootstrapSystem = nodes.nixos.system.build.toplevel;
      recoverySystem = nodes.nixos.specialisation.machine-recovery.configuration.system.build.toplevel;
    in
    ''
      import json
      nixos.start()
      nixos.wait_for_unit("multi-user.target")

      nixos.succeed("mkfs.btrfs /dev/vdb")

      with subtest("recovery disk has btrfs layout"):
          nixos.succeed("btrfs filesystem show /dev/vdb")

      nixos.succeed("mkdir -p /mnt/recovery")
      nixos.succeed("mount /dev/vdb /mnt/recovery")

      nixos.succeed("btrfs subvolume create /mnt/recovery/@root")
      nixos.succeed("btrfs subvolume create /mnt/recovery/@persist")

      with subtest("recovery subvolume exists"):
          nixos.succeed("btrfs subvolume show /mnt/recovery/@root")
          nixos.succeed("btrfs subvolume show /mnt/recovery/@persist")

      nixos.succeed("umount /mnt/recovery")

      with subtest("boots recovery specialisation"):
          nixos.succeed("${recoverySystem}/bin/switch-to-configuration boot")
          nixos.succeed("sync")
          nixos.crash()
          nixos.wait_for_unit("multi-user.target", timeout=60)

      with subtest("recovery filesystem layout is mounted"):
          nixos.succeed('test -e /run/ephemeral-root-reset-ran')
          nixos.succeed('test "$(findmnt -n -o FSTYPE /)" = btrfs')
          nixos.succeed('test "$(findmnt -n -o FSROOT /)" = /@root')

          nixos.succeed("mountpoint /persist")
          nixos.succeed('test "$(findmnt -n -o FSTYPE /persist)" = btrfs')
          nixos.succeed('test "$(findmnt -n -o FSROOT /persist)" = /@persist')

      with subtest("write persistent and ephemeral probes"):
          nixos.succeed(
              "echo persistent > /var/lib/nixos/machine-recovery-test"
          )
          nixos.succeed(
              "echo ephemeral > /etc/machine-recovery-ephemeral"
          )

      with subtest("persistent probe reaches persist subvolume"):
          nixos.succeed(
              "grep -q persistent /persist/var/lib/nixos/machine-recovery-test"
          )

      with subtest("ephemeral probe is not persisted"):
          nixos.succeed(
              "grep -q ephemeral /etc/machine-recovery-ephemeral"
          )
          nixos.fail(
              "test -e /persist/etc/machine-recovery-ephemeral"
          )

      with subtest("boots back into bootstrap system"):
          entries = json.loads(nixos.succeed("bootctl list --json=short"))
          bootstrap_entry = next(entry["id"] for entry in entries if "${bootstrapSystem}/init" in entry.get("options", ""))
          nixos.succeed(f"bootctl set-oneshot {bootstrap_entry}")
          nixos.succeed("sync")
          nixos.crash()
          nixos.wait_for_unit("multi-user.target")

      with subtest("bootstrap system is not running from recovery root"):
          nixos.succeed('test "$(findmnt -n -o FSROOT /)" != /@root')

      nixos.succeed("mkdir -p /mnt/recovery")
      nixos.succeed("mount -o subvolid=5 /dev/vdb /mnt/recovery")

      with subtest("recovery subvolumes are accessible from bootstrap"):
          nixos.succeed("btrfs subvolume show /mnt/recovery/@root")
          nixos.succeed("btrfs subvolume show /mnt/recovery/@persist")
          nixos.succeed("grep -q ephemeral /mnt/recovery/@root/etc/machine-recovery-ephemeral")
          nixos.succeed("grep -q persistent /mnt/recovery/@persist/var/lib/nixos/machine-recovery-test")
      with subtest("reset ephemeral root"):
          #nixos.succeed("btrfs subvolume delete /mnt/recovery/@root")
          print(nixos.succeed("btrfs subvolume list /mnt/recovery"))
          #nixos.succeed("btrfs subvolume create /mnt/recovery/@root")

      #with subtest("root reset removes ephemeral state only"):
      #    nixos.fail("test -e /mnt/recovery/@root/etc/machine-recovery-ephemeral")
      #    nixos.succeed("grep -q persistent /mnt/recovery/@persist/var/lib/nixos/machine-recovery-test")
    '';
}
