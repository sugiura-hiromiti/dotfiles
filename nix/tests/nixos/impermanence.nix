{
  lib,
  pkgs,
  disko,
}:
let
  system = lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      (import ../../modules/nixos/features/storage/provisioning.nix { inherit disko; })
      ../../modules/nixos/features/impermanence/impermanence.nix
      { dotfiles.features.impermanence.enable = true; }
    ];
  };
  service = system.config.boot.initrd.systemd.services.impermanence-reset;
in
assert system.config.fileSystems."/persist".neededForBoot;
assert system.config.fileSystems."/nix".neededForBoot;
assert builtins.elem "sysroot.mount" service.before;
assert builtins.elem "sysroot.mount" service.requiredBy;
assert builtins.elem pkgs.btrfs-progs service.path;
assert builtins.elem pkgs.util-linux service.path;
assert builtins.elem pkgs.coreutils service.path;
pkgs.runCommandLocal "impermanence-eval-test" { } ''touch "$out"''
