{ pkgs, ... }:
pkgs.testers.runNixOSTest {
  name = "dotfiles.impermanence-vm";
  nodes = {
    machine = { };
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
  '';
}
