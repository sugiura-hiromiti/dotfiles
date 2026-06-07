{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.darwin.users;
  accountUsers = cfg.accounts;
  accountUid = name: accountUsers.${name}.uid or null;
  accountNamesWithUid = lib.filter (name: accountUid name != null) (lib.attrNames accountUsers);
  accountHomeDirectory =
    name: account:
    let
      configuredHomeDirectory = account.homeDirectory or null;
    in
    if configuredHomeDirectory != null then configuredHomeDirectory else "/Users/${name}";
in
{
  options.dotfiles.darwin.users = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to configure Darwin users from account metadata.";
    };

    accounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            uid = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "Darwin user UID. Null skips users.knownUsers/users.users generation.";
            };

            homeDirectory = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Darwin user home directory. Null defaults to /Users/<name>.";
            };
          };
        }
      );
      default = { };
      description = "Darwin account metadata used to generate nix-darwin users.";
    };

    shell = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Login shell for generated Darwin users. Null derives a Nushell path from each user's home directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    users = {
      knownUsers = accountNamesWithUid;
      users = lib.listToAttrs (
        map (name: {
          inherit name;
          value = {
            uid = accountUid name;
            home = lib.mkDefault (accountHomeDirectory name accountUsers.${name});
            shell = lib.mkDefault (
              if cfg.shell != null then
                cfg.shell
              else
                "${accountHomeDirectory name accountUsers.${name}}/.nix-profile/bin/nu"
            );
          };
        }) accountNamesWithUid
      );
    };
  };
}
