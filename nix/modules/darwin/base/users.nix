{
  accounts,
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.darwin.users;
  accountUsers = accounts.users or { };
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
  options.dotfiles.darwin.users.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure Darwin users from account metadata.";
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
            shell = lib.mkDefault "/Users/${name}/.nix-profile/bin/nu";
          };
        }) accountNamesWithUid
      );
    };
  };
}
