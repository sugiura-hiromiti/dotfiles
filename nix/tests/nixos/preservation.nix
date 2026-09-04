{ pkgs, preservation }:
pkgs.testers.runNixOSTest {
  name = "dotfiles.preservation";
  testScript = ''
    machine.start(allow_reboot=True)
    machine.wait_for_unit("default.target")

    with subtest("persistent storage is mounted"):
      machine.succeed("mountpoint /persist")
    with subtest("/var/lib/nixos is managed by Preservation"):
      machine.succeed("mountpoint /var/lib/nixos")
    with subtest("writes reach persistent storage"):
      machine.succeed(
        "echo preserved > /var/lib/nixos/preservation-test"
      )
      machine.succeed(
        "grep -q preserved /persist/var/lib/nixos/preservation-test"
      )
    with subtest("state survives reboot"):
      machine.reboot()
      machine.wait_for_unit("default.target")
      machine.succeed(
        "grep -q preserved /var/lib/nixos/preservation-test"
      )
      machine.succeed(
        "grep -q preserved /persist/var/lib/nixos/preservation-test"
      )
    machine.shutdown()
  '';
  nodes = {
    machine = { ... }: {
      imports = [
        preservation.nixosModules.default
        ../../modules/nixos/base/boot.nix
        ../../modules/nixos/features/preservation.nix
      ];
      dotfiles = {
        features = {
          preservation = {
            enable = true;
          };
        };
      };
      networking = {
        useNetworkd = true;
      };
      virtualisation = {
        memorySize = 1024;
        emptyDiskImages = [ 64 ];
        fileSystems."/persist" = {
          device = "/dev/vdb";
          fsType = "ext4";
          neededForBoot = true;
          autoFormat = true;
        };
      };
    };
  };
}
