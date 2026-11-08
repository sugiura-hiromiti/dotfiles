# Game Feature Responsibility Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `game` を型付き構成要素を持つ Feature に整理し、Home Manager の PrismLauncher 導入と NixOS の永続化要求を共通の意味上の契約へ統一する。

**Architecture:** `dotfiles.features.game.{enable,prismlauncher.enable}` を Home Manager と NixOS それぞれのモジュールで宣言し、対象 Target の Program オプションに `lib.mkDefault true` を加える。既存 Variant は両 Target の Feature を有効化する暫定接続点として残し、Preservation と PrismLauncher Program の実装責務は維持する。

**Tech Stack:** NixOS modules、Home Manager、Nixpkgs（既存の `flake.lock`）、`nix/checks.nix`、`nix/tests/`。

**Spec:** `docs/superpowers/specs/2026-11-08-game-feature-responsibility-design.md`（実装時は本計画と一緒にリポジトリへ配置すること）。

## Global Constraints

- **スコープは `game` Feature のみ。** Variant 全体の廃止、他の Feature、Runtime、Host/Account、共通ターゲット解決ロジックは変更しない。
- API を Home Manager と NixOS の双方で `game.enable: bool = false`, `game.prismlauncher.enable: bool = true` に一致させる。
- `game.programs` の文字列リストは撤去し、汎用ループによる任意 Program の有効化をやめる。移行前に利用箇所を再検索する。
- Feature のオーケストレーションは `lib.mkDefault true` に限定し、他モジュールの独立した Program 設定を強制的に取り消さない。
- `dotfiles.programs.prismlauncher.preserveData` と既存 Preservation 機構の実装を再設計しない。
- NixOS と Home Manager の設定は異なる評価文脈。共通オプションの値の自動同期を主張しない。
- 開始前に最新 HEAD、`git status --short` / `jj status`、既存の変更を確認し、他人の未コミット変更を保持する。
- Baseline: `1a7bce2293da159f31c93d8178acf31c427b0e5a`。実装前に最新の差分を確認する。

## Review Focus

1. Feature が無効でも子オプションの既定 `true` による副作用がないこと（Tasks 1, 2）。
2. Feature が有効でも子オプション `false` なら HM 導入・NixOS 永続化要求の両方が発生しないこと（Tasks 1, 2）。
3. 他モジュールが Program を有効化した場合、Feature 無効化によってその設定が壊れないこと（Tasks 1, 2）。
4. `game` から `preserveData = mkDefault true` を要求した場合でも、Program の明示的な `false` と Preservation 無効化を尊重すること（Task 2）。
5. Variant から両 Target を有効化した際、旧 NixOS の直接 `preserveData` 設定に依存せず、X12 と aarch64 Linux の意図した結果を維持すること（Task 3）。

---

### Task 1: Home Manager の型付き `game` API

**Files:**
- Modify: `nix/modules/home/features/game.nix`
- Create: `nix/tests/home/game.nix`
- Modify: `nix/checks.nix` — Linux 非 VM checks に `game-home` を追加（他 Target 用テストは後続 Task）。

**Interfaces:**
- Consumes: `dotfiles.programs.prismlauncher.enable: bool`（既存 Program オプション）。
- Produces: `dotfiles.features.game.enable: bool = false` と `dotfiles.features.game.prismlauncher.enable: bool = true`。

- [ ] **Step 1: 実行環境と旧 API の利用者を再確認。** `jj status` または `git status --short`、`rg -n 'game\.programs|features\.game|prismlauncher\.enable' nix` を実行する。明示的な `game.programs` 利用者が新たに見つかった場合は、勝手に破壊的移行をせず用途と必要な移行を報告する。
- [ ] **Step 2: Home Manager 評価テストを先に作成。** `nix/tests/home/game.nix` に、固定した `pkgs` と最小 Home Manager configuration（`home-manager.lib.homeManagerConfiguration`、`home.username`、`home.homeDirectory`、`home.stateVersion = "26.05"`）を用いたテストを作成する。Feature と実際の PrismLauncher Program モジュールを import し、`config.dotfiles.programs.prismlauncher.enable` および `config.programs.prismlauncher.enable` を評価する。ケースは次のとおり：
  - `game.enable = false`（子オプション既定 true）→ Program は Feature から有効化されない。
  - `game.enable = true`（子オプション既定 true）→ Program 有効化。
  - `game.enable = true; game.prismlauncher.enable = false` → Feature による Program 有効化なし。
  - `game.enable = false; dotfiles.programs.prismlauncher.enable = true` → 独立した Program 設定は有効。
  - `game.enable = true; dotfiles.programs.prismlauncher.enable = false` → 明示的な Program 無効化は優先。
  - `nix/profiles/variants/game/home.nix` を取り込んだ場合 → `game.enable = true` が既定となる。より強い `game.enable = false` による明示的な無効化も尊重される。
  上記 assertion を評価して `pkgs.runCommandLocal "game-home-eval-test" { } ''touch "$out"''` を返す。`nix/checks.nix` の Linux 非 VM checks に `game-home = import ./tests/home/game.nix { inherit lib pkgs home-manager; };` を追加する。**フレークが新規テストを認識できるよう Git の追跡対象にする。**
- [ ] **Step 3: Red を確認。** `nix build --no-update-lock-file '.#checks.x86_64-linux.game-home'`。既存 `game.prismlauncher.enable` 未実装による失敗を記録する。外部要因の失敗を Red と誤認しない。
- [ ] **Step 4: Feature API を変更。** `game.programs` を削除。`prismlauncher.enable` を `bool`／default `true` として宣言し、`lib.mkIf (cfg.enable && cfg.prismlauncher.enable)` 下で `dotfiles.programs.prismlauncher.enable = lib.mkDefault true` とする。既存 Program モジュールは変更しない。
- [ ] **Step 5: Green を確認。** `nix build --no-update-lock-file '.#checks.x86_64-linux.game-home'` が exit 0 で成功することを確認する。評価環境にないアーキテクチャでは、同じフレークチェックが提供される現地プラットフォーム用システムを `nix eval` で確認してから実行する。
- [ ] **Step 6: 対象ファイルの差分をレビューしコミット。** `game.programs` の残存を確認し、Task 1 に属するファイルだけを VCS の既定運用（jj/git）に従って記録する。

### Task 2: NixOS の `game` Feature と永続化要求

**Files:**
- Create: `nix/modules/nixos/features/game.nix`
- Modify: `nix/modules/nixos/default.nix` — `./features/game.nix` を import。
- Modify: `nix/profiles/variants/game/nixos.nix` — NixOS 側の直接 `preserveData` 設定を Feature の有効化へ変更。
- Create: `nix/tests/nixos/game.nix`
- Modify: `nix/checks.nix` — Linux 非 VM checks に `game-nixos` を追加。
- Preserve as-is: `nix/modules/nixos/programs/prismlauncher/default.nix` と `nix/modules/nixos/features/impermanence/preservation.nix`。

**Interfaces:**
- Consumes: `dotfiles.programs.prismlauncher.preserveData: bool`（既存）と `dotfiles.features.preservation.enable: bool`（既存）。
- Produces: `dotfiles.features.game.enable: bool = false` と `dotfiles.features.game.prismlauncher.enable: bool = true`。Feature 条件成立時は `dotfiles.programs.prismlauncher.preserveData = lib.mkDefault true` を追加する。

- [ ] **Step 1: NixOS 評価テストを先に作成。** `nix/tests/nixos/game.nix` で `lib.nixosSystem` を使用。最小構成に新 `game` モジュールと既存 PrismLauncher Program、必要な `preservation` のモジュールと `specialArgs.accounts.primary` を組み合わせる（現行 `nix/tests/nixos/impermanence-vm.nix` を参照）。次の assertion を検証する：
  - `game.enable = false` → `preserveData = false`（Feature の追加設定なし）。
  - `game.enable = true` → `preserveData = true`。
  - `game.enable = true; game.prismlauncher.enable = false` → `preserveData = false`。
  - `game.enable = false; preserveData = true` → 独立した Program 要求は保持。
  - `game.enable = true; preserveData = false` → 明示的な Program 設定が `mkDefault true` より優先。
  - `game.enable = true; preservation.enable = false` → Feature が永続化基盤を有効化せず、PrismLauncher 永続化ディレクトリも生成しない。
  - `game.enable = true; preservation.enable = true` → 既存 Program が `preservation.preserveAt."/persist".users.<primary>.directories` に `.local/share/PrismLauncher` を追加する。
  - `nix/profiles/variants/game/nixos.nix` を取り込むと、Feature は既定有効。明示的な `game.enable = false` で Feature 起因の要求は消える。
  Assertion は遅延評価でスキップされないよう、強制評価してから `pkgs.runCommandLocal "game-nixos-eval-test" { } ''touch "$out"''` を返す。既存の Program モジュールを変更してテストを通すのは禁止。`nix/checks.nix` に `game-nixos = import ./tests/nixos/game.nix { inherit lib pkgs preservation; };` を登録する。
- [ ] **Step 2: Red を確認。** `nix build --no-update-lock-file '.#checks.x86_64-linux.game-nixos'`。未作成の Feature モジュールやオプションによる失敗を記録する。
- [ ] **Step 3: NixOS Feature を追加。** `nix/modules/nixos/features/game.nix` に HM 側と同一名・同一型・同一既定値の option を定義し、`lib.mkIf (cfg.enable && cfg.prismlauncher.enable) { dotfiles.programs.prismlauncher.preserveData = lib.mkDefault true; }` の構造で実装。`nix/modules/nixos/default.nix` に import する。
- [ ] **Step 4: NixOS Variant の責務を移管。** `nix/profiles/variants/game/nixos.nix` の `dotfiles.programs.prismlauncher.preserveData` 直接指定を削除し、`dotfiles.features.game.enable = lib.mkDefault true` に置換。HM 側 Variant の Feature 有効化宣言は維持する。
- [ ] **Step 5: Green を確認。** `nix build --no-update-lock-file '.#checks.x86_64-linux.game-nixos'` が exit 0。NixOS 設定評価は Host・Facter に依存しない最小構成で成立すること。必要であれば aarch64-linux 用の同名チェックも評価する。
- [ ] **Step 6: 対象ファイルの差分をレビューしコミット。** Preservation の既存所有者を変更していないこと、`mkForce` が入っていないこと、NixOS Variant の直接 `preserveData` が除去されていることを確認。

### Task 3: 既存 Host との統合検証と完了報告

**Files:**
- Verify: `nix/profiles/hosts/x86_64-linux-a/meta.nix` と `nix/profiles/hosts/aarch64-linux-a/meta.nix`（通常変更不要）。
- Verify: `nix/checks.nix`、`nix/profiles/variants/game/{home,nixos}.nix`。
- No changes expected: `nix/lib/{hosts,targets,resolve-profiles}.nix`、他 Feature。

**Interfaces:**
- Consumes: Tasks 1–2 の両ターゲット用 Feature API。
- Produces: `game` リファクタリングが構成・評価レベルで両 Host の既存意図を維持するという実証結果。

- [ ] **Step 1: 全パターンの単体評価。** 次を実行し、終了コードと出力を記録する。
  ```nu
  nix build --no-update-lock-file '.#checks.x86_64-linux.game-home' '.#checks.x86_64-linux.game-nixos'
  ```
  （CI runner が aarch64-linux の場合は、そのプラットフォームのチェックも確認。）
- [ ] **Step 2: 実際の Flake target 名を発見。** 次のコマンドで利用可能な NixOS / Home Manager ターゲット名を取得し、X12 と aarch64 Linux の対応ターゲットを特定する。
  ```nu
  nix eval --no-update-lock-file --json '.#nixosConfigurations' --apply builtins.attrNames
  nix eval --no-update-lock-file --json '.#homeConfigurations' --apply builtins.attrNames
  ```
- [ ] **Step 3: 両 Host の Feature の有効値を直接評価。** 発見した各 Target に対して `config.dotfiles.features.game.enable`、`config.dotfiles.features.game.prismlauncher.enable` を検証し、Home Manager 側は `config.dotfiles.programs.prismlauncher.enable` と `config.programs.prismlauncher.enable`、NixOS 側は `config.dotfiles.programs.prismlauncher.preserveData` を検証する。特に `session-gui` と `session-tty`、theme による予期しない変化がないことを確認する。
- [ ] **Step 4: Flake / lint の確認。** 次を実行し、変更起因の不具合と既存 CI 環境問題を区別する。
  ```nu
  nix flake check --no-build --no-update-lock-file .
  nix build --no-update-lock-file '.#checks.x86_64-linux.deadnix' '.#checks.x86_64-linux.statix'
  ```
  フォーマッタを用いる場合、無関係のファイルへの変更を残さない。過去に Catppuccin と CI runner の問題が発生しているため、単体テストの成功と全体 CI の成功を混同しない。
- [ ] **Step 5: 最終差分レビューと実装報告。** 変更ファイル・オプション API・両 Host の実効値・実行したコマンド・PASS/FAIL・実機検証有無を報告する。既存 Variant の存続と独立 Target 評価の制約も記述する。今回の `game` 以外の Feature や Variant 全廃には進まない。

## Completion / stop boundary

- 目標達成は **「Feature 自身の定義の制御」と「既存 Program 独立設定の保持」を確認した時点**。`game.enable = false` でも独立した Program 宣言は生きてよい。
- 実際に確認していない CI テスト、OS 起動、PrismLauncher の実行を成功と記述しない。
- 実装計画はここで停止。次のリファクタリングには自動的に移行しない。