{
  lib,
  nixpkgs,
  disko,
  preservation,
  catppuccin,
  nix-agent,
  profileModules,
  systemSpecialArgs,
}:
let
  nixosProfileModule = config: {
    dotfiles.nixos.users.accounts = lib.mkDefault (
      lib.mapAttrs (_: account: {
        description = account.description or null;
        extraGroups = account.extraGroups or [ ];
        authorizedKeys = account.authorizedKeys or [ ];
        inherit (account) uid;
        homeDirectory = account.homeDirectory or null;
      }) config.accounts.users
    );
  };
  modulesFor =
    config:
    [
      disko.nixosModules.disko
      preservation.nixosModules.default
      (nixosProfileModule config)
      ../nixos/configuration.nix
    ]
    ++ profileModules "nixos" config
    ++ [
      catppuccin.nixosModules.catppuccin
      nix-agent.nixosModules.default
    ];
in
{
  build =
    config:
    nixpkgs.lib.nixosSystem {
      inherit (config) system;
      specialArgs = systemSpecialArgs config;
      modules = modulesFor config;
    };
}
