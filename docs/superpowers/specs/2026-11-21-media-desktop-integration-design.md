# Media / desktopIntegration リファクタリング設計

**状態:** Draft  
**基準:** [Feature API と内部 Composition — 設計原則](./2026-11-10-feature-capability-provider-contract-design.md)

## 責務

| Component | 責務 |
| --- | --- |
| `media` | 再生・制作・CLI・Web Playback・メディア固有 MIME |
| `desktopIntegration` | Browser の選択・提供、既定 Browser、Portal 等 |
| `dotfiles.programs.mpv` | mpv の提供と固有設定 |
| Browser Provider | Browser の実効パッケージ、起動方法、Desktop Entry 等の共通情報 |

依存方向は **`media → desktopIntegration → Browser Provider`**。desktopIntegration は Media を参照しない。Media MIME は Media 自身が `xdg.mimeApps` に寄与し、委譲しない。Browser 固有の Web Playback adapter は Media が所有する。

## 公開 API と既定値

| API | 契約 |
| --- | --- |
| `media.mpv.enable` | Media から mpv を要求 |
| `media.graphics.krita.enable` | Media から Krita を要求 |
| `media.cli.{enable,packages}` | CLI ツール群を構成 |
| `media.webPlayback.enable` | 選択 Browser から mpv への連携 |
| `media.mimeApps.{enable,defaultApplications}` | メディア固有 MIME の直接管理 |
| `desktopIntegration.browser.selected` | Browser Provider を選択（`null` 可） |
| `desktopIntegration.mimeApps.{enable,defaultApplications}` | Browser・デスクトップ固有 MIME の管理 |
| `dotfiles.programs.mpv.{enable,package,settings}` | mpv の独立した提供と固有設定 |

Browser 選択の基本既定値は `null`、**Linux GUI Profile は `lib.mkDefault "glide"`** とする。Media の Web Playback は Linux GUI かつ Browser 選択ありの場合に既定で有効、`selected = null` なら既定で無効とする。明示的に有効化して Browser がない場合は契約エラー。

## 不変条件

1. **依存:** Linux GUI で `media.enable = true` なら `desktopIntegration.enable = lib.mkDefault true` を要求し、最終的に無効なら契約エラー。TTY では要求しない。macOS GUI への適用は対応実装が完成する Phase 4 からとする。
2. **Browser:** 選択 Provider の最終値から Browser を実際に提供する。Niri の Browser 起動行も選択 Provider から生成し、`selected = null` なら出力しない。Browser の選択だけでは既定ハンドラーを保証せず、`desktopIntegration.mimeApps.enable` が有効な場合に HTTP/HTTPS/HTML/XHTML の4関連付けを保証する。
3. **desktopIntegration MIME:** Host が `inode/directory` など一部の MIME を指定しても、未指定の自動関連付けは保持する。選択 Browser と異なる `text/html` 等の上書きは、MIME が有効なら最終値を検証して契約エラーにする。Nix module の優先順位を尊重し、黙って上書きしない。
4. **Web Playback:** 有効時は選択 Browser、対応 adapter、URL を渡して実行できる mpv が必須。mpv の標準提供経路は **`dotfiles.programs.mpv` の最終的な非 null package** とし、その実体を adapter が使用する。`media.mpv.enable = false` でも Program が独立して有効なら利用できる。単なる `programs.mpv.enable` フラグや未申告の `home.packages` だけで提供を保証したとはみなさない。
5. **Media MIME:** Media が直接適用し、既存の `video/*`・`audio/*`・`image/*` → `mpv.desktop` を維持する。Web Playback の実行ファイルとは別に、参照する `mpv.desktop` の実効的な提供を検証する。他の Feature の MIME 寄与を停止しない。
6. **Terminal 非依存:** Media の自動有効化だけで Terminal を必須にしない。desktopIntegration の FileChooser は、Terminal がある場合 `termfilechooser`、ない場合 `gtk` を既定にする。明示的に `termfilechooser` を要求し Terminal がなければ契約エラー。
7. **最終値・無効化:** Host・Account・Profile の上書きに最終構成を追従させる。Feature・子機能の `false` は自身の寄与を停止するだけで、共有 Program を排他的に無効化しない。未対応機能を黙って無視せず、自動フォールバックで矛盾を隠さない。

## 環境・移行の境界

Linux GUI を先行実装する。TTY は CLI・mpv を利用可能とし、GUI 専用機能を既定で無効化する。非対応機能の明示的有効化は契約エラー。

**Darwin は Phase 4 まで現行の Media → Glide・ff2mpv 経路を維持する。** Phase 2・3 では Linux の Browser 所有権を移す一方、Darwin で `media.programs` を削除・無効化しない。Phase 4 で新 Provider 経路の成立を確認し、同じ変更で旧経路を撤去する。macOS の既定 Browser 保証は対応実装完了後にのみ公開する。

Home Manager と NixOS の同名 Feature は自動同期しない。共通 Provider Framework、Player Provider、MIME 委譲 API は導入しない。
