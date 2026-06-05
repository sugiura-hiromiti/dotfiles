# ~/.config/nix/flake.nix
# -----------------------------------------------------------------------------
# 概要
# - profiles/hosts/<host>/meta.nix が system/accounts/targets/roles/variants を定義
# - home/ が Home Manager、nixos/ が NixOS、nix-darwin/ が macOS 設定の入口
# - profiles/{platforms,systems,hosts} は各target入口から解決して取り込み
# - runtime-contexts.nix が theme/session と追加 variants の対応を定義
#
# 使い方
# 1) 新しい端末を追加:
#    profiles/hosts/<host>/meta.nix を作成し system/accounts/targets を指定
#    (必要なら同ディレクトリに nixos.nix / hardware-configuration.nix)
# 2) 反映:
#    - Home Manager: nix run nixpkgs#home-manager -- switch --flake .#<host>
#    - NixOS: sudo nixos-rebuild switch --flake .#<host>
#    - macOS: sudo nix run nix-darwin -- switch --flake .#<host>
# 3) まとめて更新:
#    nix run .#update
#    - git stage -> flake.lock 更新/stage -> Home Manager 反映
#    - macOS なら nix-darwin / NixOS なら nixos-rebuild も実行
#    - account は未指定なら current user を使う
#    - theme/session は未指定なら実行時に検出する
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
    # neovim-nightly-overlay = {
    #   url = "github:nix-community/neovim-nightly-overlay";
    # };
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
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
    systems = {
      url = "github:nix-systems/default";
    };
    # paneru = {
    #   url = "github:karinushka/paneru";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    # niri-flake = {
    #   url = "github:sodiboo/niri-flake";
    # };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
        noctalia-qs = {
          follows = "noctalia-qs";
        };
      };
    };
    noctalia-qs = {
      url = "github:noctalia-dev/noctalia-qs";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
    # zen-browser = {
    #   url = "github:0xc000022070/zen-browser-flake";
    #   inputs = {
    #     nixpkgs = {
    #       follows = "nixpkgs";
    #     };
    #     home-manager = {
    #       follows = "home-manager";
    #     };
    #   };
    # };
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      # neovim-nightly-overlay,
      catppuccin,
      nur,
      flake-parts,
      treefmt-nix,
      systems,
      # paneru,
      # niri-flake,
      noctalia,
      noctalia-qs,
      # zen-browser,
    }:
    let
      inherit (nixpkgs) lib;
      runtimeContexts = import ./runtime-contexts.nix;
      hostRegistry = import ./lib/hosts.nix {
        inherit lib runtimeContexts;
        hostDir = ./profiles/hosts;
      };
      inherit (hostRegistry) hosts hostNames;
      runtime = import ./lib/runtime.nix {
        inherit lib runtimeContexts;
      };
      targets = import ./lib/targets.nix {
        inherit
          lib
          hosts
          hostNames
          runtime
          ;
      };
      inherit (targets) mkTargetConfigs targetConfigNamesForSystem;
      hm-conf =
        {
          system,
          accountName,
          account,
          host,
          hostName,
          accounts,
          primaryAccountName,
          primaryAccount,
          roles,
          variants,
          theme,
          session,
          hasGui,
          has_gui,
          ...
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            overlays = [
              # neovim-nightly-overlay.overlays.default
              nur.overlays.default
              # niri-flake.overlays.niri
            ];
            inherit system;
          };
          extraSpecialArgs = {
            inherit theme;
            inherit session;
            inherit hasGui;
            inherit has_gui;
            inherit system;
            inherit host;
            inherit hostName;
            inherit accountName;
            inherit account;
            inherit accounts;
            inherit primaryAccountName;
            inherit primaryAccount;
            inherit roles;
            inherit variants;
            # inherit paneru;
          };
          modules = [
            ./home
            catppuccin.homeModules.catppuccin
            # paneru.homeModules.paneru
            noctalia.homeModules.default
            # zen-browser.homeModules.twilight
          ];
        };
      nixos-conf =
        {
          system,
          host,
          hostName,
          accounts,
          accountNames,
          primaryAccountName,
          primaryAccount,
          roles,
          variants,
          theme,
          session,
          hasGui,
          has_gui,
          ...
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit system;
            inherit theme;
            inherit session;
            inherit hasGui;
            inherit has_gui;
            inherit host;
            inherit hostName;
            inherit accounts;
            inherit accountNames;
            inherit primaryAccountName;
            inherit primaryAccount;
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
          host,
          hostName,
          accounts,
          accountNames,
          primaryAccountName,
          primaryAccount,
          roles,
          variants,
          theme,
          session,
          hasGui,
          has_gui,
          ...
        }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit system;
            inherit theme;
            inherit session;
            inherit hasGui;
            inherit has_gui;
            inherit host;
            inherit hostName;
            inherit accounts;
            inherit accountNames;
            inherit primaryAccountName;
            inherit primaryAccount;
            inherit roles;
            inherit variants;
            # inherit paneru;
          };
          modules = [
            ./nix-darwin
          ];
        };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        treefmt-nix.flakeModule
      ];
      systems = import systems;
      flake = {
        #
        nixosConfigurations = mkTargetConfigs "nixos" nixos-conf;
        homeConfigurations = mkTargetConfigs "home" hm-conf;
        darwinConfigurations = mkTargetConfigs "darwin" darwin-conf;
      };
      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        let
          homeTargets = targetConfigNamesForSystem "home" system;
          nixosTargets = targetConfigNamesForSystem "nixos" system;
          darwinTargets = targetConfigNamesForSystem "darwin" system;
          currentSystemHosts = lib.filter (host: hosts.${host}.system == system) hostNames;
          currentSystemAccounts = lib.unique (
            lib.concatMap (host: hosts.${host}.accountNames) currentSystemHosts
          );
          currentSystemHostAliases = lib.genAttrs currentSystemHosts (host: hosts.${host}.matchNames);
          currentSystemHostDefaultSessions = lib.genAttrs currentSystemHosts (
            host: hosts.${host}.runtime.defaultSession
          );
          validThemes = lib.attrNames runtimeContexts.themes;
          validSessions = lib.attrNames runtimeContexts.sessions;
          formatters = import ./formatters { inherit lib pkgs; };
          repoMaintenancePackages = with pkgs; [
            formatters.editorTools
            deadnix
            fish
            nil
            statix
          ];
          nvimMaintenancePackages = with pkgs; [
            lua-language-server
            luajitPackages.luarocks
            tree-sitter
          ];
        in
        {
          treefmt = {
            imports = [
              ./treefmt.nix
            ];
          };

          checks = import ./checks.nix {
            inherit
              lib
              pkgs
              self
              ;
            targetConfigNames = {
              home = homeTargets;
              nixos = nixosTargets;
              darwin = darwinTargets;
            };
          };

          apps.update = import ./apps/update.nix {
            inherit
              lib
              pkgs
              system
              currentSystemHosts
              currentSystemAccounts
              currentSystemHostAliases
              currentSystemHostDefaultSessions
              validThemes
              validSessions
              homeTargets
              nixosTargets
              darwinTargets
              ;
          };

          devShells.default = pkgs.mkShell {
            name = "dotfiles-maintenance";
            inputsFrom = [
              config.treefmt.build.devShell
            ];
            packages = repoMaintenancePackages;
          };

          devShells.nvim = pkgs.mkShell {
            name = "dotfiles-nvim";
            inputsFrom = [
              config.treefmt.build.devShell
            ];
            packages = repoMaintenancePackages ++ nvimMaintenancePackages;
          };
        };
    };
}
