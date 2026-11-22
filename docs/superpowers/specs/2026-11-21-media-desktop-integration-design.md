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
| `desktopIntegration.fileChooser.{enable,mode}` | ファイル選択を構成し、単独の外部委譲も可能にする |
| `desktopIntegration.orgProtocol.enable` | Emacs による org-protocol URL 処理を要求 |
| `sessionGui.session` | 管理対象 GUI セッションの選択（Portal の Session Provider 選択元） |
| `dotfiles.programs.mpv.*` | mpv の独立した提供と固有設定 |

`fileAssociations` の公開値はアプリ／Provider の論理名を使い、`mpv.desktop` 等の OS 固有 ID を必須としない。MIME 型や Desktop Entry を直接扱う高度な設定は実装固有の設定として区別する。既存の任意 MIME 上書きについては移行手段を提供し、黙って捨てない。

**依存:** `media → desktopIntegration → Browser Provider`。desktopIntegration は Media に依存しない。Media と desktopIntegration はそれぞれ自分の関連付けポリシーを管理し、OS ごとの内部 adapter に適用する。XDG Portal は汎用 FileChooser と同義ではなく、Linux の実装固有設定として残す。

## Desktop Session Provider と Portal の適用先

**Compositor 固有の実装差は内部で吸収するが、FileChooser Provider と Session Provider は分ける。** FileChooser が `gtk` / `termfilechooser` のどちらを使うかは `desktopIntegration.fileChooser` が決める。Session Provider は、その結果を **どのセッション用 Portal 設定に出力するか**を決める。Browser Provider とも独立する。全 compositor 共通の Provider Framework は導入しない。

- 選択元は既存の `dotfiles.features.sessionGui.session`。現行の `niri` に加え `sway` の識別を扱えるようにする。ただし `sessionGui.enable = false` なら `sessionGui.session` の既定値 `niri` から実セッションを推測しない。Sway を *識別すること* と Sway の設定一式を管理・起動することは別契約であり、Sway の全面的な管理を必須にしない。
- 選択された Session Provider は `portalConfigName`（`niri` / `sway`）と、必要なセッション固有 Portal 既定ポリシーを内部で提供する。既知のセッションでは `niri-portals.conf` / `sway-portals.conf` の `org.freedesktop.impl.portal.FileChooser` に**選択済み backend** を設定し、`default`・`Inhibit` 等の無関係な既存ポリシーは保存する。
- `sessionGui` が無効でもセッション固有の Portal 設定が必要な独立 Home では、従来の `portal.configName = "sway"` のような**明示した適用先**を尊重する。新 Session Provider による移行が必要なら対応する公開設定と移行先を示し、旧指定を無視しない。
- セッションを識別できない場合だけ、共通 `portals.conf` に FileChooser **1キーのみ**を自動生成できる。ただし利用者側の `sway-portals.conf` などが共通設定より優先され得るため、これは best-effort であり**明示 `mode = "terminal"` の実効保証には使わない**。保証に必要な Session Provider またはセッション固有の `portal.configName` がないときは理由付き契約エラーとし、対応する選択方法を案内する。
- `portal.configName = "common"` を Host が明示し、`secretBackend` 等も指定している既存ケースは自動生成とは区別する。明示ポリシーの内容・出力先を維持するか同等の移行先を提供する。`fileChooser.enable = false` は既存どおり外部 chooser に委譲する。

### FileChooser の選択優先順位

`auto` は Terminal が有効なら `termfilechooser`、無効なら `gtk` を選ぶ。**明示的な選択が `auto` より優先する。** 旧 API が存続する Phase 2 では `portal.fileChooser.backend = "gtk"` は Terminal ON でも GTK、`backend = null` は chooser の選択・パッケージ・ラッパーを提供しない。Phase 3 の `fileChooser.enable = false` に同じ委譲 semantics を移す。

## 機能別の不変条件

1. **Browser:** Glide の既定選択は **GUI Profile が明示的に採用する場合**（Linux GUI、Phase 4 後の Darwin GUI）、または **GUI の Media が要求する場合**に限る（Media は `desktopIntegration.browser.selected = lib.mkDefault "glide"` を要求）。**GUI Profile も Media もない desktopIntegration 単独構成では `selected` の既定は `null`** とし、Browser を導入せず関連付けも生成しない。既存の Qutebrowser 単独構成では `browser.selected = "qutebrowser"`、Glide 単独または Glide + Qutebrowser 構成では `browser.selected = "glide"` に明示的に移行し、従来の Browser 4関連付けを維持する。Host の明示的な `null` や別 Provider は優先する。選択 Provider の最終値から実体と起動コマンドを導出する。Niri の自動起動は desktopIntegration 有効かつ選択ありのときのみ寄与し、Niri 単独構成は壊さない。
2. **Web Playback:** GUI で **選択 Browser・対応 adapter・実効 mpv が揃えば**既定 ON、いずれかがなければ既定 OFF。明示 ON なのに欠ける場合は契約エラー。`media.mpv.enable = false` でも独立した mpv Program が提供されれば既定 ON にできる。実行ファイルは `config.programs.mpv.finalPackage` から導出し、スクリプトを含む最終ラッパーを使う。Firefox の新規プロファイルでは ff2mpv 拡張が実際に有効化され、ブラウザーから送信できることまで保証する。Qutebrowser は **Linux と Darwin の両方**で選択時に既存の `,m` 操作から現在の URL を最終 mpv に渡せることを保証する（その OS での Browser 実装が提供可能なことを前提とし、未対応なら黙って構成しない）。選択変更・無効化後は Media 由来の拡張・native host・キー割り当てを残さない。
3. **File associations:** `desktopIntegration.fileAssociations` は Browser の HTML・XHTML・HTTP・HTTPS と独立したファイル関連付けを扱い、`media.fileAssociations` はメディア関連付けを直接管理する。新 API は既定で部分上書きを合成するが、**`fileAssociations.autoDefaults.enable = false` と明示規則の組合せで自動規則を全停止**できる。この場合 Browser 4件の自動関連付け保証も停止する。自動規則が有効なら選択 Browser と矛盾する最終値を検出する。旧 `mimeApps.defaultApplications` の明示値は *desktopIntegration の寄与を* 全置換するが、Media 等の独立した MIME 寄与は停止しない。無断で新 API の部分上書きへ変換しない。
4. **実効関連付け:** Linux adapter は既存の `video/*`・`audio/*`・`image/*` を維持し、Home Manager による具体 MIME 型への展開を利用する。`video/mp4` に mpv 固定の別規則を重複追加しない。動画の論理ハンドラーを変更したら `video/mp4` の実効値も追従すること、競合するシステム側既定値がある状態でも選択結果が正しいことを照会する。実効 mpv と `mpv.desktop` の存在は別々に検証する。Darwin adapter は OS の関連付け機構を使用する。
5. **FileChooser:** `fileChooser.enable = true` では `mode = auto | system | terminal` を選択し、GTK / termfilechooser / macOS 標準機構への割当ては内部で行う。`auto` は Terminal がなくても利用できる Provider を選ぶ。**GUI の Media 単独構成も Terminal を必須としない。** Linux では Session Provider または明示的なセッション指定に基づくセッション固有 Portal 設定を優先し、選択済み backend を反映する。セッション不明時に自動生成する共通 `portals.conf` は FileChooser の1キーだけを出力するが、セッション固有ファイルが優先され得るため明示 `terminal` の保証には使わない。`default`・`Inhibit` 等は自動生成時に上書きしない。**Host が `portal.configName = "common"` と `secretBackend` 等を明示した構成は別扱い**とし、既存の指定済みポリシーを保持する（公開 API の整理で移行が必要なら同等の明示的な移行先を用意する）。**`fileChooser.enable = false` は chooser の選択・パッケージ・専用設定だけを停止**し、Portal の他の設定を残して外部の chooser を利用できる（旧 `portal.fileChooser.backend = null` に相当）。明示した方式を実現できなければ契約エラー。
6. **Org Protocol:** URL 処理は目的ベースの `orgProtocol.enable` で選択し、OS 固有の登録方法は内部に隠す。Darwin では対応 adapter ができるまで既定 OFF、明示 ON は理由付き契約エラー。Linux の `xdg.desktopEntries.org-protocol` を Darwin に出力しない。
7. **依存・無効化:** GUI で Media が有効なら desktopIntegration を `mkDefault true` で要求する（Darwin への適用は Phase 4）。TTY では要求しない。Feature／子機能の OFF は自身の寄与だけを停止し、共有 Program を排他的に停止しない。Host の上書き後の実効構成が公開契約に反する場合はエラーとし、黙って無視しない。

## 既定動作と実装可能性

GUI では Browser = Glide、Web Playback = ON、mpv = ON を維持する。Linux GUI では Krita を `media.graphics.krita.enable` から要求し、関連付けも有効にする。TTY では CLI と mpv を維持し、Web Playback・Krita・Media 関連付けは既定 OFF（TTY MIME は既存動作からの意図的変更）。

**機能の既定 ON は、選択 Browser と実効 mpv など必要な実装が揃う場合に限る。** 未実装の機能を別 OS で黙って無視せず、明示 ON は契約エラーにする。Darwin の関連付けなど未提供の機能は、実装が完成するまで保証しない。実装差異を Host の公開設定へ漏らして埋め合わせることもしない。

## 移行保証

Phase 2・3 は Linux の提供経路だけを切り替え、Darwin の既存 Glide・ff2mpv を維持する。Phase 4 は Darwin GUI の Glide／Web Playback の同等性（**2ホスト×2テーマ＝4 Home 構成**の `Glide.app`、選択プロファイルの ff2mpv 拡張、manifest の `allowed_extensions` と拡張 ID の一致、Browser 連携から最終 mpv への URL 到達）を確認してから旧経路を撤去する。macOS 実機の起動確認は別途必要。

旧 `desktopIntegration.mimeApps.defaultApplications` の全置換動作は Phase 2 まで維持する。Phase 3 では同一結果になる `fileAssociations.autoDefaults.enable = false` と明示規則への移行を案内し、明示的な旧設定は黙って意味を変更せずエラーにする。旧 `media.mimeApps`・`desktopIntegration.portal.fileChooser.backend` 等も、機能 API への移行先または実装固有設定の継続先を示す。

**非目標:** 共通 Provider Framework、Player Provider、MIME 委譲 API、Home Manager と NixOS の自動同期。
