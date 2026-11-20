# Media / desktopIntegration リファクタリング設計

**状態:** Draft  
**基準:** [Feature API と内部 Composition](./2026-11-10-feature-capability-provider-contract-design.md)

## 責務と公開 API

| Component | 契約 |
| --- | --- |
| `media` | mpv・Krita・CLI の要求、Web Playback、メディア MIME |
| `desktopIntegration` | Browser 選択・提供、Browser MIME、Portal |
| `dotfiles.programs.mpv` | mpv の独立した提供と固有設定 |
| Browser Provider | 実効 Browser の package・起動情報・Desktop Entry |

依存方向は **`media → desktopIntegration → Browser Provider`**。desktopIntegration は Media を参照しない。Media MIME は `media.mimeApps.{enable,defaultApplications}` が `xdg.mimeApps` に直接寄与する。mpv 固有設定は `dotfiles.programs.mpv.settings` に置き、Media は `media.mpv.enable` で要求する。Krita は `media.graphics.krita.enable`、CLI は `media.cli.{enable,packages}`、Web Playback は `media.webPlayback.enable` で制御する。

## 環境別の既定値

| 環境 | Browser 選択 | mpv | Krita | Web Playback | Media MIME |
| --- | --- | --- | --- | --- | --- |
| Linux GUI | `glide` | ON | ON | ON* | ON |
| Linux TTY | `null` | ON | OFF | OFF | **OFF** |
| Darwin GUI（Phase 4 後） | `glide` | ON | OFF | ON* | OFF |

*Web Playback は選択 Browser が `null` でない場合に既定 ON。`null` の場合は既定 OFF、明示 ON は契約エラー。Browser 選択の基本既定値は `null` とし、Linux GUI／Phase 4 後の Darwin GUI Profile が `lib.mkDefault "glide"` を指定する。Host の上書きを尊重する。

**TTY の Media MIME 無効化は既存動作からの意図的変更**（現行テストは ON を期待）。以前決めた「TTY に GUI 固有の関連付けを要求しない」を優先する。TTY の CLI・mpv は維持し、明示的な非対応要求はエラーにする。

## 不変条件

1. **Feature 依存:** Linux GUI では `media.enable = true` が `desktopIntegration.enable = lib.mkDefault true` を要求し、最終的に OFF ならエラー。Darwin GUI では Phase 4 から適用し、旧経路と同時切替する。TTY では要求しない。
2. **Browser:** `desktopIntegration.browser.selected` は Provider または `null`。選択された Browser は実効的に提供される。`null` は提供を要求しない。Niri の起動行は **desktopIntegration が有効かつ Browser が選択されている**ときのみ Provider の実効コマンドから構成し、Niri 単独利用には desktopIntegration の import を要求しない。
3. **Browser MIME:** `desktopIntegration.mimeApps.enable` が ON の Linux GUI で、HTML・XHTML・HTTP・HTTPS の4件を選択 Browser に関連付ける。他の MIME 型への Host の部分的な指定はこれらを消さない。選択 Browser と矛盾する4件への明示上書きは、最終値を検証して契約エラーとする（`selected = null` では Browser 関連付けを要求しない）。
4. **Web Playback:** 有効時は Browser、対応 adapter、実効 mpv が必要。実行ファイルは Home Manager の **`config.programs.mpv.finalPackage`** から導出し、`programs.mpv.scripts` 等を含む最終ラッパーを使う。単なる `programs.mpv.enable` フラグや PATH 上の `mpv` で提供を推測しない。`media.mpv.enable = false` でも、独立した mpv Program が実効的に提供されればよい。adapter は選択変更・無効化時に Media 由来の寄与を残さない。
5. **Media MIME:** 現行の `video/*`・`audio/*`・`image/* = mpv.desktop` は **設定互換**として維持する。ただし実際の既定アプリの保証対象は個別に列挙した MIME 型（初期対象 `video/mp4`）とし、競合するシステム側関連付けがある場合も `mpv.desktop` が選択されるよう具体的な関連付けを設定・検証する。Web Playback の実行ファイルとは独立して `mpv.desktop` の存在と関連付けを確認する。[XDG MIME 仕様](https://specifications.freedesktop.org/mime-apps/latest/default.html) の具体型優先に従う。
6. **OS 固有機能:** Darwin で desktopIntegration を ON にしても Linux 固有の XDG Portal・XDG MIME・termfilechooser を自動的に有効にしない。これらの既定値は対応 Linux GUI のみ ON とし、Darwin で明示的に要求された未対応機能は契約エラー。
7. **Terminal 非依存:** Media は Terminal を必須にしない。FileChooser の既定は Terminal があれば `termfilechooser`、なければ `gtk`。Terminal 不在で `termfilechooser` を明示選択した場合はエラー。
8. **最終値と無効化:** Host・Account・Profile の通常の優先順位による上書きを尊重する。Feature や子機能の OFF は自身の寄与を停止し、共有 Program を排他的に停止しない。実効構成の矛盾を検出し、暗黙のフォールバックで隠さない。

## Darwin 移行の保証

Phase 2・3 では Darwin の `media.programs` → Glide および ff2mpv 旧経路を維持する。Phase 4 で Darwin GUI の Browser Provider 既定 `glide`、Web Playback 既定 ON、desktopIntegration の OS 条件を同時に導入し、**既存 Darwin Home 2件**で `Glide.app`、Glide 向け native messaging manifest、最終 mpv への URL 到達を確認してから旧経路を外す。Darwin 実機での起動確認は別途必要。

**非目標:** 共通 Provider Framework、Player Provider、MIME 委譲 API、Home Manager と NixOS の自動同期。
