# Media / desktopIntegration リファクタリング実装計画

**前提:** [Media / desktopIntegration リファクタリング設計](../specs/2026-11-21-media-desktop-integration-design.md)

## Phase 1 — mpv Program 分離

**対象:** `nix/modules/home/programs/mpv/default.nix`（新規）、`nix/modules/home/features/media.nix`。

- mpv 固有設定を Program module に移し、Media は有効化を要求する。
- Media OFF での mpv 単独利用、Media ON での実効 mpv OFF を検証する。
- `nix/modules/home/default.nix` は Program ディレクトリを自動検出するため、登録変更は不要。

## Phase 2 — Browser Provider

**対象:** `nix/modules/home/features/desktop-integration/`、`nix/modules/home/programs/{glide,firefox,qutebrowser}/`。

- 最小 Provider 契約を定義し、Glide・Firefox・Qutebrowser を登録する。
- `desktopIntegration.browser.selected` から選択 Browser を提供する。`null` を許可する。
- `mime-apps.nix` の暗黙的な Glide 優先を廃止し、既定 Browser の関連付けを `mimeApps.enable` で制御する。
- 未登録 Provider、選択 Program の無効化、Provider の最終値と実効 Program の不一致を検証する。

## Phase 3 — Media Composition

**対象:** `nix/modules/home/features/media.nix`、`nix/modules/home/programs/firefox-common.nix`、各 Browser module、Media / desktopIntegration の Home テスト。

- `media.programs` と `media.firefoxIntegration` を廃止し、mpv・Krita・CLI の要求と Web Playback adapter に分離する。
- ff2mpv の extension / native messaging host、Qutebrowser の mpv 起動処理について Media 由来の寄与を明確にする。
- Media MIME の直接管理を維持し、ハンドラーの実効状態を検証する。
- GUI で desktopIntegration を既定有効化し、明示的 OFF は契約エラーにする。
- TTY では GUI 専用機能を既定無効にし、明示的な非対応要求を検出する。

## Phase 4 — macOS 対応

**対象:** `nix/modules/home/features/desktop-integration.nix`、OS 固有 module、`nix/profiles/variants/desktop-integration/home.nix`、関連テスト。

- Linux 専用処理を切り分け、macOS Browser 統合を実装・検証する。
- 対応後に macOS GUI の desktopIntegration 依存と Profile 既定値を有効化する。

## 検証・完了条件

`nix/tests/home/desktop-integration-mime.nix` と `nix/tests/system/desktop-integration.nix` を更新し、必要な Media / Browser Provider テストを `nix/checks.nix` に登録する。

公開 API の上書き、Feature の無効化、Provider 切り替え、依存先欠如、GUI/TTY 差分に対し、最終的な Program・Browser・Web Playback・MIME の状態が設計仕様と一致することを確認する。
