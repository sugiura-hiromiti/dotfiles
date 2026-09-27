{
  lib,
  nix-darwin,
  profileModules,
  systemSpecialArgs,
}:
let
  darwinProfileModule = config: {
    dotfiles.darwin = {
      core.primaryUser = lib.mkDefault config.primaryAccountName;
      users.accounts = lib.mkDefault (
        lib.mapAttrs (_: account: {
          uid = account.uid or null;
          homeDirectory = account.homeDirectory or null;
        }) config.accounts.users
      );
    };
  };
  modulesFor =
    config:
    [
      (darwinProfileModule config)
      ../nix-darwin
      (import ./system-identity.nix { targetConfig = config; })
    ]
    ++ profileModules "darwin" config
    ++ config.deployment.modules;
in
{
  inherit modulesFor;
  build =
    config:
    nix-darwin.lib.darwinSystem {
      inherit (config) system;
      specialArgs = systemSpecialArgs config;
      modules = modulesFor config;
    };
}
