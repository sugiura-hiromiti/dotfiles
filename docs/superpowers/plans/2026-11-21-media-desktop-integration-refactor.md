# Media / desktopIntegration リファクタリング実装計画

**前提:** [Media / desktopIntegration リファクタリング設計](../specs/2026-11-21-media-desktop-integration-design.md)

## Phase 1 — mpv Program 分離

**対象:** `nix/modules/home/programs/mpv/default.nix`（新規）、`nix/modules/home/features/media.nix`。

- mpv 固有設定を Program に移す。既存の `autofit-large` は `autofit-larger` に修正する。
- Program が最終的な非 null package を実際に配布する契約を実装する。未申告の `home.packages` への偶然の混入は提供経路として扱わない。
- Media OFF の mpv 単独利用と、Media が要求する mpv が不在・package null の場合を検証する。
- 生成した `mpv.conf` を実際の mpv に読み込ませ、オプションエラーがないことを確認する。
- `nix/modules/home/default.nix` は Program ディレクトリを自動検出するため、登録変更は不要。

## Phase 2 — Browser Provider と Linux GUI 移行

**対象:** `nix/modules/home/features/desktop-integration/`、`nix/modules/home/programs/{glide,firefox,qutebrowser}/`、`nix/modules/home/programs/niri/{default.nix,config/config.kdl}`、`nix/profiles/variants/desktop-integration/home.nix`、`nix/modules/home/features/media.nix`。

- Provider を登録し、Linux GUI Profile に `browser.selected = lib.mkDefault "glide"` を設定する。通常の既定値は `null`。
- Linux での Browser 提供を Media の `programs` リストから desktopIntegration に**同時移行**する。Darwin の旧 Glide・ff2mpv 経路は維持する。
- Niri の固定 `spawn-at-startup "glide"` を選択 Provider の実効コマンドに置き換え、`null` では起動行を省く。
- desktopIntegration の自動 MIME を属性単位で合成可能にする。ディレクトリのみの Host 上書きでは Browser 4関連付けを保持し、異なる `text/html` 上書きは契約エラーとする。
- Provider の切り替え、`null`、未登録 Provider、実効 package の上書き、Niri の起動行、既存 Linux GUI の Glide 関連付けをテストする。

## Phase 3 — Media Composition（Linux）

**対象:** `nix/modules/home/features/media.nix`、`nix/modules/home/programs/firefox-common.nix`、各 Browser module、`nix/modules/home/features/desktop-integration/portal.nix`、関連テスト。

- Linux 側の `media.programs`・`media.firefoxIntegration` 利用を Web Playback adapter と個別 Program 要求に置き換える。**Darwin 用の旧オプションと ff2mpv 経路は残す。**
- Web Playback の Linux GUI 既定値を「Browser 選択あり」に連動させる。`null` なら既定無効、明示 ON なら契約エラー。
- Web Playback は選択 Browser から**実行可能な mpv に URL が届くこと**を検証する。Media MIME は独立して **`mpv.desktop` の提供**を検証する。`programs.mpv.enable = true; programs.mpv.package = null;` だけでは成功とみなさない。
- Media MIME の直接管理を維持し、TTY では GUI 固有機能を既定無効にする。
- Linux GUI で desktopIntegration を `mkDefault true` により要求し、明示 OFF を契約エラーにする。
- Terminal がない場合の FileChooser 既定 backend を `gtk` にし、Terminal がある既存ホストは `termfilechooser` のまま維持する。明示 `termfilechooser` + Terminal 不在は引き続き契約エラー。
- **Terminal 無効の Media-only Home**、TTY、Glide/Firefox/Qutebrowser、Browser 未選択、MIME 競合、共有 mpv の単独提供を検証する。

## Phase 4 — Darwin の一括移行

**対象:** `nix/modules/home/features/desktop-integration.nix`、OS 固有 module、`nix/profiles/variants/desktop-integration/home.nix`、`nix/modules/home/features/media.nix`、各 Browser module、Darwin 関連テスト。

- Darwin GUI の Browser Provider・Web Playback・desktopIntegration を実装し、旧 Glide・ff2mpv と同等の実効構成を検証する。
- **同じ移行で** Darwin の `media.programs` と旧 ff2mpv 経路を撤去し、Media → desktopIntegration 依存を有効化する。Profile の `mkDefault false` と `mkDefault true` を競合させない。
- Phase 2・3 の中間状態と Phase 4 完了状態について、Darwin GUI の評価・Glide 提供・ff2mpv 連携が継続することを確認する。

## 検証・完了条件

`nix/tests/home/desktop-integration-mime.nix`、`nix/tests/system/desktop-integration.nix` を更新し、必要な Provider / Media テストを `nix/checks.nix` に登録する。

既存の `desktop-integration-home`・`desktop-integration-mime`・`desktop-integration-hosts` に加え、各 Phase で Linux GUI・TTY・Darwin GUI の実効構成を検証する。全体の `flake check` が失敗する場合は、テスト失敗と整形・作業ツリーに起因する失敗を区別して記録する。
