# Media / desktopIntegration リファクタリング設計

**状態:** Draft  
**基準:** [Feature API と内部 Composition — 設計原則](./2026-11-10-feature-capability-provider-contract-design.md)

## 責務

| Component | 責務 |
| --- | --- |
| `media` | 再生・制作・CLI・Web Playback・メディア固有 MIME の構成 |
| `desktopIntegration` | Browser の選択・提供、既定 Browser、Portal 等 |
| `dotfiles.programs.mpv` | mpv の提供と固有設定 |
| Browser Provider | Browser の交換に必要な共通情報 |

依存方向は **`media → desktopIntegration → Browser Provider`**。desktopIntegration は Media を参照しない。Media MIME は Media 自身が Home Manager の `xdg.mimeApps` に寄与し、desktopIntegration に委譲しない。

## 公開 API

| API | 契約 |
| --- | --- |
| `media.mpv.enable` | Media から mpv の提供を要求 |
| `media.graphics.krita.enable` | Media から Krita の提供を要求 |
| `media.cli.{enable,packages}` | CLI ツール群を構成 |
| `media.webPlayback.enable` | 選択 Browser から mpv への連携を要求 |
| `media.mimeApps.{enable,defaultApplications}` | メディア固有 MIME を直接構成 |
| `desktopIntegration.browser.selected` | Browser Provider を選択（`null` 可） |
| `dotfiles.programs.mpv.{enable,settings}` | Media と独立して mpv を構成 |

mpv の固有設定は Program module が所有する。Media は Browser の選択 API を重複して持たない。Browser Provider は実際に共有する提供情報だけを持ち、Web Playback の Browser 別 adapter は Media 側に置く。

## 不変条件

1. **GUI 依存:** GUI で `media.enable = true` なら、`desktopIntegration.enable = lib.mkDefault true` を要求する。最終的に無効なら契約エラー。TTY では要求しない。
2. **Browser:** 選択 Provider は実効的に提供される。`selected = null` は Browser を要求しないことを意味する。既定 Browser の MIME 関連付けは `desktopIntegration.mimeApps.enable` が有効な場合のみ保証する。
3. **Web Playback:** 有効時は選択 Browser、対応 adapter、実効的な mpv が必須。いずれかが欠ければ契約エラー。`media.mpv.enable = false` でも、mpv が別経路で提供されていれば利用できる。
4. **Media MIME:** Media が独立して適用する。既知のハンドラーは実効的な提供と整合させる。既存の `video/*`・`audio/*`・`image/*` → `mpv.desktop` という方針は変更しない。
5. **無効化:** Feature や子機能の `false` は、その Feature からの寄与を止める。他の利用者による共有 Program や MIME の利用は禁止しない。
6. **実効保証:** Host・Account・Profile の上書きを Nix module の通常の優先順位で合成し、最終的な公開 API 値に従う。矛盾を検出し、未対応機能を黙って無視したり自動フォールバックしたりしない。

## 対応環境

Linux GUI を最初の実装対象とする。TTY では CLI・mpv を利用可能とし、Web Playback・Media MIME・GUI 専用 Krita 要求は既定で無効にする。非対応環境で明示的に有効化された機能は契約エラーとする。

macOS GUI での desktopIntegration 依存と既定 Browser 設定は、対応実装を追加してから保証対象に含める。Home Manager と NixOS の同名 Feature は自動同期しない。

**非目標:** 共通 Provider Framework、Player Provider、Browser の二重選択 API、MIME 委譲 API、共有 Program の排他的停止。
