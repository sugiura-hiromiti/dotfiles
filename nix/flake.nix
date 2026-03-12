# ~/.config/nix/flake.nix
# -----------------------------------------------------------------------------
# 概要
# - profiles/hosts/<host>/meta.nix が system/user/targets/roles/variants を定義
# - home/ が Home Manager、nixos/ が NixOS、nix-darwin/ が macOS 設定の入口
# - profiles/{platforms,systems,users,hosts} は home/ から解決して取り込み
# - secret.nix で user/theme/has_gui/host(任意) を供給
#
# 使い方
# 1) 新しい端末を追加:
#    profiles/hosts/<host>/meta.nix を作成し system/user/targets を指定
#    (必要なら同ディレクトリに nixos.nix / hardware-configuration.nix)
# 2) 反映:
#    - Home Manager: nix run nixpkgs#home-manager -- switch --flake .#<host>
#    - NixOS: sudo nixos-rebuild switch --flake .#<host>
#    - macOS: sudo nix run nix-darwin -- switch --flake .#<host>
# 3) まとめて更新:
#    nix run .#update
#    - git stage -> flake.lock 更新 -> Home Manager 反映
#    - macOS なら nix-darwin / NixOS なら nixos-rebuild も実行
#    - ホスト名は secret.host を優先、無ければ "<system>-<user>"
# -----------------------------------------------------------------------------
{
  description = "nixxxxxxxxxxxxxxxxxxxxxxxx";
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs?ref=nixos-unstable";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
    };
    awww = {
      url = "git+https://codeberg.org/LGFae/awww?ref=main";
    };
    catppuccin = {
      url = "github:catppuccin/nix";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
    systems = {
      url = "github:nix-systems/default";
    };
    paneru = {
      url = "github:karinushka/paneru";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      neovim-nightly-overlay,
      awww,
      catppuccin,
      nur,
      flake-parts,
      systems,
      paneru,
    }:
    let
      lib = nixpkgs.lib;
      secret = import ./secret.nix { };
      defaultUser = secret.user;
      theme = secret.theme;
      has_gui = secret.has_gui;
      defaultHost = if secret ? host then secret.host else null;

      hostDir = ./profiles/hosts;
      hostEntries = builtins.readDir hostDir;
      hostNames = lib.attrNames (lib.filterAttrs (_: type: type == "directory") hostEntries);
      mkHost =
        host:
        let
          meta = import (hostDir + "/${host}/meta.nix");
          system = meta.system;
          user = meta.user or defaultUser;
          uid = meta.uid or null;
          hostName = meta.hostName or host;
          roles = meta.roles or [ ];
          variants = meta.variants or [ ];
          targets = meta.targets or [ "home" ];
        in
        {
          inherit
            host
            system
            user
            uid
            hostName
            roles
            variants
            targets
            ;
        };
      hosts = builtins.listToAttrs (
        map (host: {
          name = host;
          value = mkHost host;
        }) hostNames
      );
      mkTargetConfigs =
        target: mkConf:
        lib.listToAttrs (
          lib.concatMap (
            host:
            let
              h = hosts.${host};
            in
            lib.optionals (lib.elem target h.targets) [
              {
                name = host;
                value = mkConf h;
              }
            ]
          ) hostNames
        );
      hm-conf =
        {
          system,
          user,
          host,
          hostName,
          roles,
          variants,
          targets,
          ...
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            overlays = [
              neovim-nightly-overlay.overlays.default
              nur.overlays.default
            ];
            inherit system;
          };
          extraSpecialArgs = {
            inherit theme;
            inherit user;
            inherit has_gui;
            inherit system;
            inherit awww;
            inherit host;
            inherit hostName;
            inherit roles;
            inherit variants;
            inherit paneru;
          };
          modules = [
            ./home
            catppuccin.homeModules.catppuccin
            paneru.homeModules.paneru
          ];
        };
      nixos-conf =
        {
          system,
          user,
          host,
          hostName,
          roles,
          variants,
          targets,
          ...
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit system;
            inherit theme;
            inherit user;
            inherit host;
            inherit hostName;
            inherit roles;
            inherit variants;
          };
          modules = [
            ./nixos/configuration.nix
            catppuccin.nixosModules.catppuccin
          ];
        };
      darwin-conf =
        {
          system,
          user,
          uid,
          host,
          hostName,
          roles,
          variants,
          targets,
          ...
        }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit system;
            inherit user;
            inherit uid;
            inherit host;
            inherit hostName;
            inherit roles;
            inherit variants;
            inherit paneru;
          };
          modules = [
            ./nix-darwin
          ];
        };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;
      flake = {
        #
        nixosConfigurations = mkTargetConfigs "nixos" nixos-conf;
        homeConfigurations = mkTargetConfigs "home" hm-conf;
        darwinConfigurations = mkTargetConfigs "darwin" darwin-conf;
      };
      perSystem =
        {
          pkgs,
          system,
          ...
        }:
        let
          host = if defaultHost != null then defaultHost else "${system}-${defaultUser}";
        in
        {

          apps.update = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "update-script" ''
                set -e
                git stage .
                nix flake update
                nix run nixpkgs#home-manager -- switch --flake .#${host}

                if [ $(uname) = "Darwin" ]; then
                  sudo nix run nix-darwin -- switch --flake .#${host}
                elif grep -qi nixos /etc/os-release; then
                  sudo nixos-rebuild switch --flake .#${host}
                fi
              ''
            );
          };
        };
    };
}
