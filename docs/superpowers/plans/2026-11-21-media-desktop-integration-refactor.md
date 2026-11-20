# Media / desktopIntegration リファクタリング実装計画

**前提:** [設計仕様](../specs/2026-11-21-media-desktop-integration-design.md)

## Phase 1 — mpv Program

**対象:** `nix/modules/home/programs/mpv/default.nix`（新規）、`nix/modules/home/features/media.nix`。

- mpv 固有設定を Program に移す。`media.mpv.settings` は移行先を示して廃止する。既定設定の `autofit-large` を `autofit-larger` に修正。
- Web Playback が使う実体は `programs.mpv.finalPackage` とする。`package = null`、`scripts` によるラッパー、パッケージ上書きで評価・配布を検証する。
- `mpv.conf` を mpv に読ませ、**終了コードだけでなく標準エラーの `Error parsing option`** も検査する。Media OFF での単独 mpv 利用も確認。

## Phase 2 — Linux Browser 移行

**対象:** `nix/modules/home/features/desktop-integration/`、`nix/modules/home/programs/{glide,firefox,qutebrowser}/`、`nix/modules/home/programs/niri/{default.nix,config/config.kdl}`、Linux GUI Profile、`media.nix`。

- Linux GUI Profile に `browser.selected = lib.mkDefault "glide"` を設定し、Media から Browser Provider へ **Linux の提供経路を同時移行**。Darwin の Glide 旧経路は維持。
- Niri の固定 `spawn-at-startup "glide"` を除去。desktopIntegration が有効かつ Browser 選択ありの場合のみ、Niri の独立した任意起動コマンドに寄与させる。Niri 単独／desktopIntegration OFF・選択値あり／ON・選択値あり／`null` を検証する。
- `desktopIntegration.mimeApps.defaultApplications` の部分的な Host 上書きは未指定の自動 MIME を保持する。ディレクトリのみ上書きと Browser の `text/html` 矛盾上書きを別々に検証する。
- Provider 切替・未登録・最終パッケージ変更・既存4 MIME を検証する。
- `media.programs` の **Linux での明示的な旧設定**は移行先を示すエラーにする（Darwin では Phase 4 まで受理して実行する）。

## Phase 3 — Linux Media Composition

**対象:** `media.nix`、`nix/modules/home/programs/firefox-common.nix`、Browser module、`desktop-integration/portal.nix`、関連テスト。

- Linux の `media.firefoxIntegration` を Web Playback adapter に置き換え、旧設定の明示指定は移行エラー。Darwin の旧オプション・Glide/ff2mpv 経路は維持する。
- Browser 選択ありなら `webPlayback.enable` を既定 ON、`null` なら既定 OFF。選択変更・OFF 後に Media 由来の extension、native host、Qutebrowser key binding が残らないことを検証する。
- `programs.mpv.finalPackage` を差し替えた録画用実行ファイルに URL が渡ることを検証する。`programs.mpv.enable = true` だけ、または `package = null` で実体がない場合は不成立とする。Media MIME は別に `mpv.desktop` の存在・関連付けを検証する。
- `video/*` 等の現行設定は保持し、`video/mp4` の具体型関連付けも実装。より具体的な競合ハンドラーを持つ隔離 XDG 環境で既定アプリを問い合わせる。
- **TTY の Media MIME は意図的に OFF** に変更し、現行 TTY テストを更新。Linux GUI で Media が desktopIntegration を要求する契約を検証する。
- Terminal なしなら GTK FileChooser が成功するよう、`nix/tests/home/desktop-integration.nix` の `missingTerminal` を成功例に変更。失敗例は backend `termfilechooser` を明示する。Terminal 無効の Media-only Home を追加。

## Phase 4 — Darwin 一括切替

**対象:** `desktop-integration.nix`、Portal/MIME 等の OS 固有 module、Darwin GUI Profile、`media.nix`、Glide/ff2mpv 経路、Darwin Home テスト。

- Darwin GUI Profile に `browser.selected = lib.mkDefault "glide"` を設定し、Web Playback 既定 ON にする。desktopIntegration 自体も有効化し、従来の `mkDefault false` と競合させない。
- XDG Portal・XDG MIME・termfilechooser などは Darwin で既定 OFF。明示 ON の未対応機能はエラーとする。
- 旧経路を**同時に撤去する前提条件**として、既存 Darwin Home 2件の評価・ビルドで `Glide.app`、Glide 向け native messaging manifest、`programs.mpv.finalPackage` への URL 引き渡しを確認する。移行後も同条件を満たすこと。実機起動は別途検証。
- `media.programs`・`media.firefoxIntegration` の旧オプションを全環境で廃止し、明示的な旧設定には移行先を示すエラーを出す。

## テストと完了条件

`nix/tests/home/desktop-integration.nix`、`nix/tests/home/desktop-integration-mime.nix`、`nix/tests/system/desktop-integration.nix` を更新し、Media / Browser / Darwin のテストを `nix/checks.nix` に登録する。旧 API の明示指定が黙って無視されないことも検査する。

各 Phase で Linux GUI・TTY・Darwin GUI の**既存構成の評価・実効出力**を確認する。全体の `flake check` と整形環境由来の失敗は区別して記録する。
