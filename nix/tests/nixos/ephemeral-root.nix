{ pkgs, ... }:
let
  # Test fixture only.
  btrfsDevice = "/dev/vdb";
in
pkgs.testers.runNixOSTest {
  name = "dotfiles.ephemeral-root";
  nodes = {
    machine = { ... }: {
      imports = [ ../../modules/nixos/features/impermanence/ephemeral-root.nix ];
      dotfiles = {
        features = {
          ephemeralRoot = {
            enable = true;
            device = btrfsDevice;
          };
        };
      };
    };
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
  '';
}
