{ pkgs, ... }:
pkgs.testers.runNixOSTest {
  name = "dotfiles.ephemeral-root";
  nodes = {
    machine = { ... }: { };
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
  '';
}
