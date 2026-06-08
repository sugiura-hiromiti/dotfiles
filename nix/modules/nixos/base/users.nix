{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.nixos.users;
  mkUser =
    name: account:
    {
      isNormalUser = true;
      description = if account.description != null then account.description else name;
      inherit (account) extraGroups;
      inherit (cfg) shell;
      openssh.authorizedKeys.keys = account.authorizedKeys;
    }
    // lib.optionalAttrs (account.homeDirectory != null) {
      home = account.homeDirectory;
    }
    // lib.optionalAttrs (account.uid != null) {
      inherit (account) uid;
    };
in
{
  options.dotfiles.nixos.users = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to configure NixOS users from account metadata.";
    };

    accounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            description = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "NixOS user description. Null defaults to the account name.";
            };

            extraGroups = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Supplementary groups for the generated NixOS user.";
            };

            authorizedKeys = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "SSH authorized keys for the generated NixOS user.";
            };

            uid = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "NixOS user UID. Null lets NixOS allocate the UID.";
            };

            homeDirectory = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "NixOS user home directory. Null leaves the NixOS default.";
            };
          };
        }
      );
      default = { };
      description = "NixOS account metadata used to generate users.users entries.";
    };

    shell = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nushell;
      defaultText = "pkgs.nushell";
      description = "Login shell for generated NixOS users.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users = lib.mapAttrs mkUser cfg.accounts;
  };
}
