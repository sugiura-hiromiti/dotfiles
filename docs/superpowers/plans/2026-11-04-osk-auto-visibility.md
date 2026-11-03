# OSK Auto Visibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ホスト単位で選択できる共通 OSK 機能に、入力欄のフォーカスに応じた表示・非表示を接続する。

**Architecture:** 既存の Home Manager の `wvkbd.service` と手動切り替えを利用する。NixOS の共通 OSK feature が Fcitx アダプタのコールバックから同じユーザーのサービスにシグナルを送り、ホスト設定では feature を有効化する。

**Tech Stack:** NixOS, Home Manager, Fcitx5, fcitx-virtualkeyboard-adapter, wvkbd, systemd user services.

**Spec:** `docs/superpowers/specs/2026-11-04-osk-auto-visibility-design.md`

## Global Constraints

- ホスト名、機種名、内蔵画面名を機能の実装条件に含めない。
- 表示は SIGUSR2、非表示は SIGUSR1、手動切り替えは SIGRTMIN を使う。
- wvkbd は非表示で起動し、既存の `graphical-session.target` に従う。
- NixOS と Home Manager の両側で `dotfiles.features.osk.enable` を指定する。
- 既存の `flake.lock` の競合と無関係な編集は保持する。

## Review Focus

- 無効なホストにアダプタ設定や OSK サービスを追加しない。
- コールバックは PATH に依存せず、同じユーザーのサービスだけを制御する。
- 表示・非表示に toggle を使わず、繰り返し通知されても意図が反転しない。
- 入力メソッドの切り替えではなく、入力欄のフォーカスイベントを監視する。
- 既存の手動切り替えと GUI セッションのライフサイクルを維持する。
- 生成する Fcitx 設定でコマンド全体の引用符を保持する。

---

### Task 1: 共通のフォーカス連携とホストでの有効化

**Files:**

- Modify: `nix/modules/nixos/features/osk.nix` — アダプタの表示・非表示コマンド。
- Modify: `nix/profiles/hosts/x86_64-linux-a/nixos.nix` — 既に Home Manager で OSK を使用しているホストの有効化。
- Modify: `docs/superpowers/specs/2026-11-04-osk-auto-visibility-design.md` — 承認状態と利用手順。

**Interfaces:**

- Consumes: Home Manager が起動するユーザー単位の `wvkbd.service`。
- Produces: `i18n.inputMethod.fcitx5.settings.addons.virtualkeyboardadapter.globalSection` の `ActivateCmd` / `DeactivateCmd`。

- [x] **Step 1:** 現在の有効ホストで NixOS 側の feature が無効、コールバックが未接続であることを Nix 評価で確認する。
- [x] **Step 2:** 共通 feature に絶対パスの `systemctl --user kill --kill-whom=main` を設定し、表示・非表示それぞれのシグナルを送る。依存アダプタは `overrideAttrs` の `postPatch` で監視対象を `InputContextFocusIn` / `InputContextFocusOut` に変更する。
- [x] **Step 3:** 対象ホストの NixOS 側に `dotfiles.features.osk.enable = true` を追加する。
- [x] **Step 4:** 有効・無効のモジュール評価、実ホストの NixOS / Home Manager 設定、Fcitx 設定の引用符、既存の手動コマンドとサービス依存を確認する。期待値は有効時に表示・非表示コマンドが設定され、無効時には追加されないこと。変更したアダプタもビルドする。
- [x] **Step 5:** 変更ファイルのフォーマット・lint を実行し、別のエージェントで差分をレビューする。
- [x] **Step 6:** 設計文書に有効化と GUI での確認手順を追記し、検証結果と実機確認の残件を報告する。

設定のみの小さな変更のため、恒久的なテスト枠組みは追加せず Nix 評価で検証する。
ユーザーの「進めて」に従い、このセッションで続けて実装する。
`.git` が読み取り専用で jj の記録操作も書き込みを伴うため、現在の作業ディレクトリで編集し、コミットは行わない。

### Task 2: 外部キーボード接続中の自動表示抑止

**Files:**

- Modify: `nix/modules/nixos/features/osk.nix` — udev 判定付き表示ヘルパーと `ActivateCmd`。
- Modify: `docs/superpowers/specs/2026-11-04-osk-auto-visibility-design.md` — 動作と実機確認手順。

**Interfaces:**

- Consumes: udev input デバイスの `ID_INPUT_KEYBOARD` / `ID_BUS` / `ID_INTEGRATION` と既存の `wvkbd.service`。
- Produces: 外部キーボードがある間は SIGUSR2 を送らない `ActivateCmd`。

- [x] **Step 1:** 一時的な検証環境で udev と systemctl の入出力を置き換え、現状では USB キーボード接続中も表示信号が送られることを確認する。
- [x] **Step 2:** `writeShellApplication` で udev DB を読み、同一デバイスのキーボード属性と USB / Bluetooth バスを確認する。`ID_INTEGRATION=internal` は除外する。該当時は正常終了し、それ以外は既存の表示信号を送る。コマンドはストア内の絶対パスを使う。
- [x] **Step 3:** USB / Bluetooth キーボード、内蔵キーボード、マウス、別デバイスに分かれた属性、デバイスなし、udev 取得失敗で分岐を確認する。実機の udev 情報でも判定する。実際の表示信号は送らない。
- [x] **Step 4:** モジュールの有効・無効、実ホストの生成設定、ヘルパーのビルドと ShellCheck、Nix のフォーマットと lint を確認し、独立したエージェントでレビューする。
- [x] **Step 5:** 動作・検証結果・設定適用後に必要な GUI 確認を記録する。

ユーザーが調査結果の推奨方式による改善を指定したため、そのままこのセッションで実装する。
着脱の常駐監視や手動トグルの変更は含めない。恒久的なテスト枠組みは追加しない。
