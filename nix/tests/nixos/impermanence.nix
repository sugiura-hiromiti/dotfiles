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
      {
        dotfiles.features.impermanence.enable = true;
        system.stateVersion = "26.05";
      }
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
pkgs.runCommandLocal "impermanence-eval-test"
  {
    nativeBuildInputs = [
      pkgs.zstd
      pkgs.cpio
    ];
    initrd = system.config.system.build.initialRamdisk;
    initrdUnits = system.config.boot.initrd.systemd.contents."/etc/systemd/system".source;
  }
  ''
    for dependency in ${lib.escapeShellArgs service.requires}; do
      test -e "$initrdUnits/$dependency" || {
        echo "Missing required initrd unit: $dependency" >&2
        exit 1
      }
    done
    zstd -dc "$initrd/initrd" | cpio -it > initrd-files
    grep -qE "/bin/impermanence-root-device$" initrd-files || {
      echo "Root-device selector executable is missing from initrd" >&2
      exit 1
    }
    touch "$out"
  ''
