# Media / desktopIntegration リファクタリング設計

**状態:** Draft  
**基準:** [Feature API と内部 Composition](./2026-11-10-feature-capability-provider-contract-design.md)

## 責務と公開 API

Feature は **目的・振る舞い**を公開し、Linux / Darwin の実装差異は内部 Composition が吸収する。OS は公開 API の分類軸ではなく、Provider が契約を満たせるかの判定条件とする。

| Component / API | 契約 |
| --- | --- |
| `media` | 再生・制作・CLI・Web Playback・メディア関連付け |
| `media.mpv.enable` / `media.graphics.krita.enable` | Media から各 Program を要求 |
| `media.cli.{enable,packages}` | CLI ツール群を構成 |
| `media.webPlayback.enable` | 選択 Browser から mpv へ再生 URL を渡す |
| `media.fileAssociations.*` | メディア種類ごとの既定アプリを選択 |
| `desktopIntegration.browser.selected` | Browser Provider を選択（`null` 可） |
| `desktopIntegration.fileAssociations.*` | Browser・ファイル・URL の既定アプリを選択 |
| `desktopIntegration.fileChooser.*` | ファイル選択の動作・方式を選択 |
| `dotfiles.programs.mpv.*` | mpv の独立した提供と固有設定 |

`fileAssociations` の公開値はアプリ／Provider の論理名を使い、`mpv.desktop` 等の OS 固有 ID を必須としない。MIME 型や Desktop Entry を直接扱う高度な設定は実装固有の設定として区別する。既存の任意 MIME 上書きについては移行手段を提供し、黙って捨てない。

**依存:** `media → desktopIntegration → Browser Provider`。desktopIntegration は Media に依存しない。Media と desktopIntegration はそれぞれ自分の関連付けポリシーを管理し、OS ごとの内部 adapter に適用する。XDG Portal は汎用 FileChooser と同義ではなく、Linux の実装固有設定として残す。

## 機能別の不変条件

1. **Browser:** GUI Profile の既定 Browser は Glide（Linux GUI、Phase 4 後の Darwin GUI）。`selected = null` は Browser 提供を要求しない。選択 Provider の最終値から実体と起動コマンドを導出する。Niri の自動起動は desktopIntegration 有効かつ選択ありのときのみ寄与し、Niri 単独構成は壊さない。
2. **Web Playback:** GUI で選択 Browser があれば既定 ON、`null` なら既定 OFF。明示 ON の場合は Browser・対応 adapter・実効 mpv を必須とし、欠如すれば契約エラー。実行ファイルは `config.programs.mpv.finalPackage` から取得し、スクリプトを含む最終ラッパーを使う。選択変更・無効化後は Media 由来の拡張・native host・キー割り当てを残さない。
3. **File associations:** `desktopIntegration.fileAssociations` は選択 Browser の HTML・XHTML・HTTP・HTTPS と、独立したファイル関連付けを扱う。`media.fileAssociations` はメディア関連付けを直接管理する。Host の部分上書きでは未指定の規則を維持し、選択 Browser と矛盾する最終値は検出する。
4. **実効関連付け:** Linux adapter は既存の `video/*`・`audio/*`・`image/* → mpv.desktop` を設定互換として維持するが、実際の既定アプリを保証する型（初期 `video/mp4`）には具体型の規則と照会テストを設ける。mpv 実行ファイルの提供と `mpv.desktop` の存在は別々に検証する。Darwin adapter は対応する OS の関連付け機構を使用する。
5. **FileChooser:** 公開するのは `auto`・`system`・`terminal` 等の動作選択とし、GTK / termfilechooser / macOS 標準機構への割当ては内部で行う。`auto` は利用可能な Provider に従い、Terminal がなくても Media の利用を妨げない。明示した方式を実現できなければ契約エラー。
6. **依存・無効化:** GUI で Media が有効なら desktopIntegration を `mkDefault true` で要求する（Darwin への適用は Phase 4）。TTY では要求しない。Feature／子機能の OFF は自身の寄与だけを停止し、共有 Program を排他的に停止しない。Host の上書き後の実効構成が公開契約に反する場合はエラーとし、黙って無視しない。

## 既定動作と実装可能性

GUI では Browser = Glide、Web Playback = ON、mpv = ON を維持する。Linux GUI では Krita と関連付けを有効にする。TTY では CLI と mpv を維持し、Web Playback・Krita・Media 関連付けは既定 OFF（TTY MIME は既存動作からの意図的変更）。

**機能の既定 ON は、内部実装が提供可能な場合に限る。** 未実装の機能を別 OS で黙って無視せず、明示 ON は契約エラーにする。Darwin の関連付けなど未提供の機能は、実装が完成するまで保証しない。実装差異を Host の公開設定へ漏らして埋め合わせることもしない。

## 移行保証

Phase 2・3 は Linux の提供経路だけを切り替え、Darwin の既存 Glide・ff2mpv を維持する。Phase 4 は Darwin GUI の Glide／Web Playback の同等性（既存 Home 2件の `Glide.app`、native messaging manifest、最終 mpv への URL 到達）を確認してから旧経路を撤去する。macOS 実機の起動確認は別途必要。

旧 `media.mimeApps`・`desktopIntegration.mimeApps`・`desktopIntegration.portal.fileChooser.backend` 等の明示設定は、機能 API への移行先または実装固有設定の継続利用先を示して扱う。無効な互換設定を黙って受理しない。

**非目標:** 共通 Provider Framework、Player Provider、MIME 委譲 API、Home Manager と NixOS の自動同期。
