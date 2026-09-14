{
  lib,
  disko,
  pkgs,
  ...
}:
let
  targetSystem = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      disko.nixosModules.disko
      ../../modules/nixos/features/impermanence/impermanence.nix
      {
        dotfiles = {
          features = {
            impermanence = {
              enable = true;
            };
            storage = {
              partitionLabel = "test-system";
              provisioning = {
                disk = "/dev/vdb";
              };
            };
          };
        };
      }
    ];
  };
  diskoScript = targetSystem.config.system.build.diskoScript;
in
pkgs.testers.runNixOSTest {
  name = "dotfiles.impermanence-vm";
  nodes = {
    machine = {
      virtualisation = {
        emptyDiskImages = [ 1024 ];
      };
    };
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("test -b /dev/vdb")
    machine.succeed("${diskoScript}")
    machine.succeed("test -b /dev/disk/by-partlabel/test-system")
  '';
}
