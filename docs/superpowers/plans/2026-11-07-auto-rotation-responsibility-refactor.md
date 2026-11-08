# Auto Rotation Responsibility Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `autoRotation` の実装責務を Host から Feature に集約し、Host が機能の選択とハードウェア固有情報だけを宣言できるようにする。

**Architecture:** Host → `dotfiles.features.autoRotation` → NixOS の `services.iio-niri` / 必要な udev ルール。Feature 自身の設定はその `enable` で切り替え、別モジュールの設定を強制的に上書きしない。

**Tech Stack:** NixOS modules、Nixpkgs（flake.lock に固定）、既存の `nix/checks.nix` と `nix/tests/nixos/`。

**Spec:** `docs/superpowers/specs/2026-11-07-auto-rotation-responsibility-design.md`（本計画と一緒に渡すこと）。

## Global Constraints

- **対象は `autoRotation` のみ。** Variant 廃止、`osk` 等の改修、ディスプレイ ID の共通化はしない。
- Host から iio-niri CLI の組み立てを排除し、Feature の公開 API のみで自動回転を宣言する。
- `enable = false` は他モジュールが所有する iio-niri / udev 設定を `mkForce` 等で削除することを意味しない。
- 現状の実装は GitHub `bba6208` に基づく。**着手前にローカル HEAD と差分を確認し、ユーザーの未コミット変更を保持する**。
- 既存の Nixpkgs `services.iio-niri` を利用し、systemd や IIO の処理を再実装しない。
- 変更は小さく、検証可能な単位に限定する。実機未検証ならその旨を報告する。

## Review Focus

1. `enable = false` かつ `monitor` 未設定でも評価が成功すること。
2. `enable = true` かつ `monitor` 未設定は、分かりやすい assertion によって拒否されること。
3. `pollingSensorName = null` の場合に udev ルールが生成されないこと。
4. `enable = false` のとき他のモジュールが `services.iio-niri.enable = true` を設定しても、それを強制無効化しないこと。
5. 別 Host 由来の `monitor` / `pollingSensorName` を設定しても、Host 内に `--monitor` や udev 設定を複製せずに済むこと。

---

### Task 1: Auto Rotation Feature の責務移管（単一の独立変更）

**Files:**

- Modify: `nix/modules/nixos/features/auto-rotation.nix` — Feature API と関連設定の生成。
- Modify: `nix/profiles/hosts/x86_64-linux-a/nixos.nix` — 利用側からの宣言だけにする。
- Create: `nix/tests/nixos/auto-rotation.nix` — 最小 NixOS 評価テスト。
- Modify: `nix/checks.nix` — Linux の非 VM チェックに `auto-rotation` を追加。
- No change expected: `nix/modules/nixos/default.nix` — 既に Feature を import している。

**Interfaces:**

- Consumes: `config.dotfiles.features.autoRotation`（既存の `enable`）と Nixpkgs の `services.iio-niri`、`services.udev.extraRules`。
- Produces:
  - `dotfiles.features.autoRotation.enable`: `bool`、default `false`。
  - `dotfiles.features.autoRotation.monitor`: `nullOr nonEmptyStr`、default `null`、有効時必須。
  - `dotfiles.features.autoRotation.pollingSensorName`: `nullOr str`、default `null`、非 null の場合は有効な IIO デバイス名のみ。

- [ ] **Step 1: 作業状態とルールの所有権を確認**

  `git status --short`（または `jj status`）、対象ファイルと `flake.lock` を確認する。`rg -n 'IIO_SENSOR_PROXY_TYPE|accel_3d|autoRotation|services\.iio-niri' nix` などで依存元を調べる。履歴でこのルールが「自動回転修正」に由来することは確認済み。他の機能に必要とする証拠があれば一旦停止して判断を求める。そうでなければ「自動回転専用」として Step 2 へ。

- [ ] **Step 2: 先に失敗する評価テストを追加**

  `nix/tests/nixos/auto-rotation.nix` に既存 `nix/tests/nixos/impermanence.nix` と同様の `lib.nixosSystem` / `pkgs.runCommandLocal` パターンを用いる。**Host や Facter に依存しない最小構成**で、次をそれぞれ独立した NixOS module 評価として検証する。

  - 有効・X12 値: `services.iio-niri.enable == true`、`extraArgs == [ "--monitor" "eDP-1" ]`、`services.udev.extraRules` に対象センサー用ルールが含まれる。
  - 無効・情報なし: 評価成功、`services.iio-niri.enable == false`、センサー用ルールを含まない。
  - 有効・回避策なし: iio-niri 有効、センサー用ルールを含まない。
  - 異なる Host 値: `monitor = "DSI-1"` と別のセンサー名で、正しい引数／ルールに変換される。
  - 有効・`monitor = null`: `config.assertions` に説明的な失敗が含まれる。NixOS module の型エラーではなく assertion の失敗として確認できる設計にする。
  - 無効・別モジュールが iio-niri を有効化: 別モジュールの設定が維持される。
  - センサー名が空や不正な場合: 誤った udev ルールを生成せず設定が拒否される。

  このテストを Linux の `nonVm` チェック集合へ追加する（`nix/checks.nix` の `lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux` 内、名前 `auto-rotation`）。新規ファイルは Nix Flake で認識されるよう、テスト実行前に追跡対象に加えること。

- [ ] **Step 3: テストが現状では失敗することを確認**

  ```nu
  nix build --no-update-lock-file .#checks.x86_64-linux.auto-rotation
  ```

  期待結果: 新しい Feature オプションや仕様が未実装のため FAIL（失敗理由を記録する）。環境制約でビルドできない場合は `nix eval --no-update-lock-file --raw .#checks.x86_64-linux.auto-rotation.drvPath` まで実施し、制約を報告する。

- [ ] **Step 4: Feature の公開オプションと内部設定を実装**

  `auto-rotation.nix` に `monitor` / `pollingSensorName` を追加する。`lib.mkIf cfg.enable` の内側に `services.iio-niri.enable = true`、`extraArgs = [ "--monitor" cfg.monitor ]` 相当の設定、自動回転専用 udev ルールの生成を集約する。`monitor = null` でも `config.assertions` を安全に評価できるよう、引数生成は条件付きにする。センサー名は `^[A-Za-z0-9_.-]+$` に制限し、空文字や udev ルール文字列を破壊し得る値を拒否する。既存 `services.iio-niri` の module が担う systemd/IIO 設定は変更しない。

- [ ] **Step 5: Host の直接設定を Feature API に移行**

  `nix/profiles/hosts/x86_64-linux-a/nixos.nix` の自動回転関連を次に統一する。

  ```nix
  dotfiles.features.autoRotation = {
    enable = true;
    monitor = "eDP-1";
    pollingSensorName = "accel_3d";
  };
  ```

  旧 `services.iio-niri.extraArgs` と自動回転専用 udev ルールを削除する。`boot.kernelPackages`、`hazkey`、`osk`、`performanceTuning` など無関係な既存設定は触らない。

- [ ] **Step 6: テストを通し、実際の構成を評価**

  ```nu
  nix build --no-update-lock-file .#checks.x86_64-linux.auto-rotation
  nix flake check --no-build --no-update-lock-file .
  ```

  期待結果: PASS。さらに `nix eval` でローカルの `x86_64-linux-a` に対応する **実際に存在する** `nixosConfigurations` ターゲットの `config.services.iio-niri.enable` / `extraArgs` を確認する（ターゲット名は `nix eval --json .#nixosConfigurations --apply builtins.attrNames` 等で発見し、捏造しない）。必要に応じて `nix fmt` / `treefmt`、`deadnix`、`statix` を実施する。環境によって全体 CI が別の理由で失敗する場合は、変更起因かどうかを分けて記録する。

- [ ] **Step 7: 差分をレビューしてコミット**

  `git diff` または `jj diff` で Feature API・Host・テスト・チェック登録だけが変更されたことを確認する。未関連の既存変更を commit に含めない。作業環境の VCS 方針に従って、この変更だけをコミットする。`nix fmt` が無関係なファイルを変更した場合は元に戻す。

### Completion report

実装AIは、変更ファイル一覧、Feature API、udev 所有権の判断根拠、実行したコマンドと結果、有効/無効評価の結果、実機動作の確認有無、未解決事項を報告する。**テスト実行なしに PASS と報告しない。**

**Stop boundary:** この Task を終えたら停止。Variant 廃止や他 Feature の再設計には進まない。
