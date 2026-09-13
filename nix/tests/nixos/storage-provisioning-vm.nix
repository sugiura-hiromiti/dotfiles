{ pkgs, ... }:
pkgs.testers.runNixOSTest {
  name = "dotfiles.storage-provisioning-vm";
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
  '';
}
