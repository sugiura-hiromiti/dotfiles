{
  lib,
  pkgs,
  nixpkgs,
  source,
}:
let
  installer = import ../../installer/iso.nix {
    inherit nixpkgs source;
    system = pkgs.stdenv.hostPlatform.system;
    host = "unprobed-host";
    target = "unprobed-host--theme-dark--session-tty";
    primaryAccount = "operator";
    facterRelativePath = "nix/profiles/hosts/unprobed-host/facter.json";
  };
  service = installer.config.systemd.services.dotfiles-installer;
in
assert lib.assertMsg (
  builtins.stringLength installer.config.isoImage.volumeID <= 32
) "Installer volume labels must fit the ISO9660 limit for long host keys";
assert lib.assertMsg (
  service.serviceConfig.UMask == "0077"
) "The installer must create private password and runtime files";
assert lib.assertMsg (
  service.serviceConfig.StandardInput == "tty-force"
  && service.serviceConfig.StandardOutput == "tty"
  && service.serviceConfig.TTYPath == "/dev/tty1"
  && !installer.config.systemd.services."getty@tty1".enable
) "The installer must own tty1";
assert lib.assertMsg (lib.elem "multi-user.target"
  installer.config.systemd.services."getty@tty2".wantedBy
) "tty2 must remain available for recovery";
assert lib.assertMsg (
  lib.elem "network-online.target" service.after && lib.elem "network-online.target" service.wants
) "The installer must wait for network readiness";
assert lib.assertMsg (lib.all
  (feature: lib.elem feature installer.config.nix.settings.experimental-features)
  [
    "nix-command"
    "flakes"
  ]
) "Installer flake commands need the Nix CLI features";
pkgs.writeText "installer-iso-eval-test" "ok\n"
