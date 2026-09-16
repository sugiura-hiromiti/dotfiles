{
  lib,
  nixpkgs,
  disko,
  preservation,
  catppuccin,
  nix-agent,
  home-manager,
  home,
  mkHomeTargetConfig,
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
  homeManagerModule =
    config:
    let
      homeAccountNames = lib.optionals (lib.elem "home" config.targets) (
        lib.filter (
          accountName: lib.elem "home" config.accounts.users.${accountName}.targets
        ) config.accountNames
      );
      homeConfigFor = accountName: mkHomeTargetConfig config accountName;
    in
    {
      home-manager = {
        users = lib.genAttrs homeAccountNames (
          accountName:
          let
            homeConfig = homeConfigFor accountName;
          in
          {
            imports = home.modulesFor homeConfig;
            _module = {
              args = home.specialArgsFor homeConfig;
            };
            nixpkgs = {
              overlays = home.overlays;
            };
          }
        );
      };
    };
  modulesFor =
    config:
    [
      disko.nixosModules.disko
      preservation.nixosModules.default
      home-manager.nixosModules.home-manager
      (nixosProfileModule config)
      (homeManagerModule config)
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
