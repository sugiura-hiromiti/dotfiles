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
#    nix run --no-write-lock-file path:.#update -- --host <host> --account <account> --theme <theme> --session <session>
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
    disko = {
      url = "github:nix-community/disko";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
    preservation = {
      url = "github:nix-community/preservation";
    };
    nix = {
      url = "github:NixOS/nix";
    };
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
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
    nix-agent = {
      url = "github:JEFF7712/nix-agent";
    };
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (import ./nix/flake { inherit inputs self; });
}
