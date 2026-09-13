{ pkgs, ... }:
pkgs.testers.runNixOSTest {
  name = "dotfiles.impermanence-vm";
  nodes = {
    machine = { };
  };
}
