{
  lib,
  pkgs,
  nixpkgs,
  source,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  mkEntry = host: deployment: theme: {
    name = "${host}--deployment-${deployment}--theme-${theme}--session-tty";
    config = {
      inherit host system;
      deploymentName = deployment;
      facterRelativePath = "nix/profiles/hosts/${host}/deployments/${deployment}/facter.json";
      facterReady = false;
      accounts.primary = "operator";
    };
  };
  inherit
    (
      (import ../../flake/installer.nix {
        inherit lib nixpkgs;
        self.outPath = source;
        declaredNixosTargetEntries = [
          (mkEntry "test-host" "qemu" "dark")
          (mkEntry "test-host" "qemu" "light")
          (mkEntry "test-host" "parallels" "dark")
          (mkEntry "no-default" "qemu" "dark")
          {
            name = "foreign-system";
            config.system = "foreign-system";
          }
        ];
        declaredNixosHostsForSystem = _: [
          {
            host = "test-host";
            deploymentNames = [
              "parallels"
              "qemu"
            ];
            defaultDeploymentName = "parallels";
          }
          {
            host = "no-default";
            deploymentNames = [ "qemu" ];
            defaultDeploymentName = null;
          }
        ];
        defaultTarget =
          {
            target,
            hostName,
            deploymentName ? "parallels",
          }:
          assert target == "nixos";
          "${hostName}--deployment-${deploymentName}--theme-dark--session-tty";
      }).perSystem
        { inherit system; }
    )
    packages
    ;
  installer = import ../../installer/iso.nix {
    inherit nixpkgs source;
    system = pkgs.stdenv.hostPlatform.system;
    host = "unprobed-host";
    target = "unprobed-host--deployment-qemu--theme-dark--session-tty";
    primaryAccount = "operator";
    facterRelativePath = "nix/profiles/hosts/unprobed-host/deployments/qemu/facter.json";
  };
  service = installer.config.systemd.services.dotfiles-installer;
in
assert
  builtins.attrNames packages == [
    "installer-no-default--deployment-qemu--theme-dark--session-tty"
    "installer-selection-no-default--deployment-qemu"
    "installer-selection-test-host"
    "installer-selection-test-host--deployment-parallels"
    "installer-selection-test-host--deployment-qemu"
    "installer-test-host--deployment-parallels--theme-dark--session-tty"
    "installer-test-host--deployment-qemu--theme-dark--session-tty"
    "installer-test-host--deployment-qemu--theme-light--session-tty"
  ];
assert
  packages.installer-selection-test-host--deployment-qemu.drvPath
  == packages.installer-test-host--deployment-qemu--theme-dark--session-tty.drvPath;
assert
  packages.installer-selection-test-host.drvPath
  == packages.installer-test-host--deployment-parallels--theme-dark--session-tty.drvPath;
assert
  packages.installer-test-host--deployment-qemu--theme-dark--session-tty.installerIdentity == {
    host = "test-host";
    deployment = "qemu";
    target = "test-host--deployment-qemu--theme-dark--session-tty";
  };
assert
  packages.installer-selection-test-host.installerIdentity == {
    host = "test-host";
    deployment = "parallels";
    target = "test-host--deployment-parallels--theme-dark--session-tty";
  };
assert
  packages.installer-selection-test-host--deployment-qemu.installerIdentity == {
    host = "test-host";
    deployment = "qemu";
    target = "test-host--deployment-qemu--theme-dark--session-tty";
  };
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
pkgs.runCommandLocal "installer-iso-test" { } ''
  test -x ${service.serviceConfig.ExecStart}
  touch "$out"
''
