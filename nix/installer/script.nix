{
  lib,
  pkgs,
  toolOverrides ? { },
  paths ? { },
}:
{
  host,
  target,
  primaryAccount,
  source,
  facterRelativePath,
  efiArch,
}:
let
  layout = import ../modules/nixos/features/storage/layout.nix;
  defaults = {
    nix = lib.getExe pkgs.nix;
    nixStore = lib.getExe' pkgs.nix "nix-store";
    facter = lib.getExe pkgs.nixos-facter;
    mkpasswd = lib.getExe' pkgs.whois "mkpasswd";
    rm = lib.getExe' pkgs.coreutils "rm";
    mkdir = lib.getExe' pkgs.coreutils "mkdir";
    cp = lib.getExe' pkgs.coreutils "cp";
    chmod = lib.getExe' pkgs.coreutils "chmod";
    chown = lib.getExe' pkgs.coreutils "chown";
    install = lib.getExe' pkgs.coreutils "install";
    mv = lib.getExe' pkgs.coreutils "mv";
    ln = lib.getExe' pkgs.coreutils "ln";
    readlink = lib.getExe' pkgs.coreutils "readlink";
    lsblk = lib.getExe' pkgs.util-linux "lsblk";
    mountpoint = lib.getExe' pkgs.util-linux "mountpoint";
    umount = lib.getExe' pkgs.util-linux "umount";
    nixosInstall = lib.getExe' pkgs.nixos-install-tools "nixos-install";
    sync = lib.getExe' pkgs.coreutils "sync";
    poweroff = lib.getExe' pkgs.systemd "poweroff";
  };
  tools = defaults // toolOverrides;
  runtimePaths = {
    runtimeRoot = "/run/dotfiles-installer";
    targetAlias = layout.installerDisk;
    mountRoot = "/mnt";
  }
  // paths;
in
pkgs.writeTextFile {
  name = "dotfiles-installer-${host}";
  executable = true;
  text = ''
    #!${lib.getExe pkgs.nushell} --no-config-file
    const HOST = ${builtins.toJSON host}
    const TARGET = ${builtins.toJSON target}
    const PRIMARY_ACCOUNT = ${builtins.toJSON primaryAccount}
    const BASE_SOURCE = ${builtins.toJSON (toString source)}
    const FACTER_RELATIVE_PATH = ${builtins.toJSON facterRelativePath}
    const EFI_ARCH = ${builtins.toJSON efiArch}

    const RUNTIME_ROOT = ${builtins.toJSON runtimePaths.runtimeRoot}
    const WORK_SOURCE = ${builtins.toJSON (runtimePaths.runtimeRoot + "/source")}
    const PASSWORD_HASH = ${builtins.toJSON (runtimePaths.runtimeRoot + "/password.hash")}
    const POST_SOURCE_ROOT = ${builtins.toJSON (runtimePaths.runtimeRoot + "/post-facter-source")}
    const TARGET_ALIAS = ${builtins.toJSON runtimePaths.targetAlias}
    const MOUNT_ROOT = ${builtins.toJSON runtimePaths.mountRoot}

    const NIX = ${builtins.toJSON tools.nix}
    const NIX_STORE = ${builtins.toJSON tools.nixStore}
    const FACTER = ${builtins.toJSON tools.facter}
    const MKPASSWD = ${builtins.toJSON tools.mkpasswd}
    const RM = ${builtins.toJSON tools.rm}
    const MKDIR = ${builtins.toJSON tools.mkdir}
    const CP = ${builtins.toJSON tools.cp}
    const CHMOD = ${builtins.toJSON tools.chmod}
    const CHOWN = ${builtins.toJSON tools.chown}
    const INSTALL = ${builtins.toJSON tools.install}
    const MV = ${builtins.toJSON tools.mv}
    const LN = ${builtins.toJSON tools.ln}
    const READLINK = ${builtins.toJSON tools.readlink}
    const LSBLK = ${builtins.toJSON tools.lsblk}
    const MOUNTPOINT = ${builtins.toJSON tools.mountpoint}
    const UMOUNT = ${builtins.toJSON tools.umount}
    const NIXOS_INSTALL = ${builtins.toJSON tools.nixosInstall}
    const SYNC = ${builtins.toJSON tools.sync}
    const POWEROFF = ${builtins.toJSON tools.poweroff}

    ${builtins.readFile ./install.nu}
  '';
  checkPhase = ''
    INSTALLER_SCRIPT="$target" \
    ${lib.getExe pkgs.nushell} --no-config-file --commands \
      'if not (nu-check --debug $env.INSTALLER_SCRIPT) { exit 1 }'
  '';
}
