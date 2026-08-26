# ~/dotfiles/flake.nix
# -----------------------------------------------------------------------------
# 概要
# - nix/profiles/hosts/<host>/meta.nix が system/accounts/targets/roles/variants/runtime を定義
# - nix/home/ が Home Manager、nix/nixos/ が NixOS、nix/nix-darwin/ が macOS 設定の入口
# - nix/profiles/{os,systems,hosts} は各target入口から解決して取り込み
# - nix/runtime-contexts.nix が theme/session と runtime profile の対応を定義
# - nix/lib/target-names.nix が公開 flake target 名の形式を定義
#
# 使い方
# 1) 新しい端末を追加:
#    nix/profiles/hosts/<host>/meta.nix を作成し system/accounts/targets を指定
#    (必要なら同ディレクトリに nixos.nix / hardware-configuration.nix)
# 2) まとめて更新/反映:
#    nix run path:.#update -- --host <host> --account <account> --theme <theme> --session <session>
#    - account は未指定なら current user を使う
#    - theme/session は未指定なら実行時に検出する
#    - macOS なら nix-darwin / NixOS なら nixos-rebuild も実行
# 3) 直接 switch:
#    - Home Manager target:
#      <targetHost>--account-<account>[--theme-<theme>][--session-<session>]
#    - NixOS / macOS target:
#      <targetHost>[--theme-<theme>][--session-<session>]
#    - Home Manager: nix run nixpkgs#home-manager -- switch --flake path:.#<target>
#    - NixOS: sudo nixos-rebuild switch --flake path:.#<target>
#    - macOS: sudo -H nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake path:.#<target>
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
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
    i-have-adhd = {
      url = "github:ayghri/i-have-adhd?ref=main";
      flake = false;
    };
    interview-me = {
      url = "github:addyosmani/agent-skills?ref=main";
      flake = false;
    };
    urd = {
      url = "github:krzysztofdudek/UrdSkill?ref=main";
      flake = false;
    };
    actions-nix = {
      url = "github:nialov/actions.nix";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
        flake-parts = {
          follows = "flake-parts";
        };
      };
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      catppuccin,
      nur,
      flake-parts,
      treefmt-nix,
      # paneru,
      # niri-flake,
      nix-index-database,
      i-have-adhd,
      interview-me,
      urd,
      # zen-browser,
      actions-nix,
    }:
    let
      inherit (nixpkgs) lib;
      runtimeContexts = import ./nix/runtime-contexts.nix;
      targetNames = import ./nix/lib/target-names.nix { inherit lib; };
      hostRegistry = import ./nix/lib/hosts.nix {
        inherit lib runtimeContexts;
        hostDir = ./nix/profiles/hosts;
      };
      inherit (hostRegistry) hosts hostNames;
      runtime = import ./nix/lib/runtime.nix {
        inherit lib runtimeContexts;
      };
      targets = import ./nix/lib/targets.nix {
        inherit
          lib
          hosts
          hostNames
          runtime
          targetNames
          ;
      };
      inherit (targets) mkTargetConfigs targetConfigNamesForSystem;
      commonOverlays = [
        # neovim-nightly-overlay.overlays.default
        nur.overlays.default
        # niri-flake.overlays.niri
      ];
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = commonOverlays;
        };
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
      nixosProfileModule = config: {
        dotfiles.nixos.users.accounts = lib.mkDefault (
          lib.mapAttrs (_: account: {
            description = account.description or null;
            extraGroups = account.extraGroups or [ ];
            authorizedKeys = account.authorizedKeys or [ ];
            uid = account.uid or null;
            homeDirectory = account.homeDirectory or null;
          }) config.accounts.users
        );
      };
      commonSpecialArgs =
        config:
        {
          inherit (config)
            accounts
            configName
            hasGui
            host
            hostName
            session
            system
            os
            targetHost
            theme
            themeProfiles
            sessionProfiles

            hostRoles
            accountRoles
            effectiveRoles

            hostVariants
            accountVariants
            effectiveVariants
            ;
        }
        // lib.optionalAttrs (config ? account) {
          inherit (config) account;
        }
        // lib.optionalAttrs (config ? accountName) {
          inherit (config) accountName;
        };
      hm-conf =
        config:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor config.system;
          extraSpecialArgs = commonSpecialArgs config // {
            iHaveAdhdSkill = i-have-adhd.outPath;
            interviewMeSkill = interview-me.outPath;
            urdSkill = urd.outPath;
          };
          modules = [
            ./nix/home
            catppuccin.homeModules.catppuccin
            # paneru.homeModules.paneru
            nix-index-database.homeModules.default
            # zen-browser.homeModules.twilight
          ];
        };
      nixos-conf =
        config:
        nixpkgs.lib.nixosSystem {
          inherit (config) system;
          specialArgs = commonSpecialArgs config;
          modules = [
            (nixosProfileModule config)
            ./nix/nixos/configuration.nix
            catppuccin.nixosModules.catppuccin
          ];
        };
      darwin-conf =
        config:
        nix-darwin.lib.darwinSystem {
          inherit (config) system;
          specialArgs = commonSpecialArgs config;
          modules = [
            (darwinProfileModule config)
            ./nix/nix-darwin
          ];
        };
      supportedSystems = lib.unique (map (host: hosts.${host}.system) hostNames);
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        treefmt-nix.flakeModule
        actions-nix.flakeModules.default
      ];
      systems = supportedSystems;
      flake = {
        actions-nix = import ./nix/ci {
          inherit hosts lib;
          inherit (targets) mkTargetConfigEntries;
        };
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
          formatters = import ./nix/formatters { inherit lib pkgs; };
          repoMaintenancePackages = with pkgs; [
            formatters.editorTools
            deadnix
            fish
            nixd
            statix
          ];
          nvimMaintenancePackages = with pkgs; [
            lua-language-server
            luajitPackages.luarocks
            tree-sitter
          ];
          inherit (targets) mkTargetConfigEntries;
        in
        {
          treefmt = {
            imports = [
              ./nix/treefmt.nix
            ];
          };

          checks = import ./nix/checks.nix {
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

          apps.update = import ./nix/apps/update {
            inherit
              lib
              pkgs
              system
              hosts
              hostNames
              mkTargetConfigEntries
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
