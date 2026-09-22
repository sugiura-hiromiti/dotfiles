{
  disko,
  preservation,
  hostConfig,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  primary = hostConfig.accounts.primary;
  user = config.users.users.${primary};
  passwordPath = "/persist/etc/dotfiles/password-${primary}.hash";
  runtimePath = "${user.home}/dotfiles";
  persistent = config.preservation.preserveAt."/persist";
  directories = persistent.users.${primary}.directories;
  dotfiles = lib.filter (directory: directory.directory == runtimePath) directories;
  normalizedHome =
    lib.hasPrefix "/" user.home
    && user.home != "/"
    && lib.all (part: part != "" && part != "." && part != "..") (
      lib.tail (lib.splitString "/" user.home)
    );
  contracts = [
    {
      assertion = normalizedHome;
      message = "Installer primary home must be absolute, normalized, and non-root.";
    }
    {
      assertion =
        builtins.isInt user.uid && user.group != "" && builtins.isInt config.users.groups.${user.group}.gid;
      message = "Installer primary account requires explicit UID and primary-group GID.";
    }
    {
      assertion = user.isNormalUser && lib.elem "wheel" user.extraGroups && config.security.sudo.enable;
      message = "Installer primary account must be a normal wheel user with sudo enabled.";
    }
    {
      assertion = !config.users.mutableUsers && user.hashedPasswordFile == passwordPath;
      message = "Installer requires immutable users and the canonical persistent password file.";
    }
    {
      assertion = config.boot.loader.systemd-boot.enable && !config.boot.loader.efi.canTouchEfiVariables;
      message = "Installer requires systemd-boot with the removable fallback EFI loader.";
    }
    {
      assertion =
        config.preservation.enable
        && persistent.persistentStoragePath == "/persist"
        && builtins.length dotfiles == 1;
      message = "Installer requires the primary dotfiles directory preserved under /persist.";
    }
    {
      assertion = config.dotfiles.features.impermanence.enable;
      message = "Installer requires impermanent root.";
    }
    {
      assertion = config.hardware.facter.reportPath == hostConfig.facterPath;
      message = "Installer requires the canonical host facter report.";
    }
  ];
in
{
  imports = [
    (import ../modules/nixos/features/storage/provisioning.nix { inherit disko; })
    ../modules/nixos/features/impermanence
    preservation.nixosModules.default
  ];
  options.dotfiles.installer.metadata = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    readOnly = true;
    description = "Effective final-system contract consumed before installer disk modification.";
  };
  config = {
    _module.args.accounts = hostConfig.accounts;
    hardware.facter.reportPath = hostConfig.facterPath;
    users.mutableUsers = false;
    users.users.${primary}.hashedPasswordFile = passwordPath;
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = false;
    assertions = contracts;
    dotfiles = {
      features = {
        impermanence.enable = true;
        preservation.enable = true;
      };
      installer.metadata =
        assert lib.assertMsg (lib.all (contract: contract.assertion) contracts) (
          lib.concatMapStringsSep "\n" (contract: contract.message) (
            lib.filter (contract: !contract.assertion) contracts
          )
        );
        {
          primaryUser = {
            name = primary;
            inherit (user)
              home
              uid
              group
              isNormalUser
              extraGroups
              hashedPasswordFile
              ;
            gid = config.users.groups.${user.group}.gid;
          };
          sudoEnabled = config.security.sudo.enable;
          mutableUsers = config.users.mutableUsers;
          boot = {
            systemdBoot = config.boot.loader.systemd-boot.enable;
            canTouchEfiVariables = config.boot.loader.efi.canTouchEfiVariables;
            efiArch = lib.toUpper pkgs.stdenv.hostPlatform.efiArch;
          };
          preservation = {
            inherit runtimePath;
            backingPath = persistent.persistentStoragePath + (lib.head dotfiles).directory;
          };
        };
    };
  };
}
