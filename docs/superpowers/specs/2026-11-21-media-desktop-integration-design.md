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
| `desktopIntegration.fileChooser.{enable,mode}` | GUI アプリの FileChooser を委譲・明示選択する（TTY のファイル操作とは別） |
| `desktopIntegration.orgProtocol.enable` | Emacs による org-protocol URL 処理を要求 |
| `sessionGui.session` | dotfiles が提供する GUI セッション設定の選択（識別そのものとは分離） |
| 内部 `desktopSession.id` | 実効セッション識別（`niri` / `sway` / `null`）、Portal adapter 等が参照 |
| `dotfiles.programs.mpv.*` | mpv の独立した提供と固有設定 |

`fileAssociations` の公開値はアプリ／Provider の論理名を使い、`mpv.desktop` 等の OS 固有 ID を必須としない。MIME 型や Desktop Entry を直接扱う高度な設定は実装固有の設定として区別する。既存の任意 MIME 上書きについては移行手段を提供し、黙って捨てない。

**依存:** `media → desktopIntegration → Browser Provider`。desktopIntegration は Media に依存しない。Media と desktopIntegration はそれぞれ自分の関連付けポリシーを管理し、OS ごとの内部 adapter に適用する。XDG Portal は汎用 FileChooser と同義ではなく、Linux の実装固有設定として残す。

## Desktop Session の識別と Portal の適用先

**セッション識別、セッション設定の提供、FileChooser 選択、Portal 設定の合成を別責務にする。** `sessionGui` は Niri 等の dotfiles 管理設定を提供し、内部の実効 `desktopSession.id`（`niri` / `sway` / `null`）は対象セッションの識別だけを表す。desktopIntegration はその実効値を参照し、セッションの管理・起動自体は要求しない。全 compositor 共通の Provider Framework は作らない。

- **識別元:** 有効な `sessionGui` が管理するセッション、または Host が明示したセッション文脈から実効 ID を導出する。`sessionGui.enable = false` の場合、`sessionGui.session` の既定値 `niri` を実セッションとみなさない。Niri 以外のセッションを識別することと、そのセッションの設定・起動を dotfiles が管理することは独立。独立 Home の既存 `portal.configName = "sway"` 等は明示的な Portal 適用先として利用・移行できるが、任意の実行時 `XDG_CURRENT_DESKTOP` を評価時に推測しない。
- **Session Provider:** 既知の ID と `niri-portals.conf` / `sway-portals.conf` などの対応先を内部で解決する。FileChooser Provider は backend の実体を提供し、Portal Composition は必要な設定と Host の明示ポリシーを合成する。Provider は Portal の全機能を一括所有しない。
- **`fileChooser.mode = "auto"`:** セッション／OS の既定動作に委譲する。**FileChooser の backend 選択・追加 backend パッケージ・専用ラッパー・強制設定を desktopIntegration から寄与しない。** Terminal の有無により自動的に `termfilechooser` / `gtk` を選んで書き込む旧案は撤回する。Session Provider / OS の既存設定を尊重し、未構成環境で chooser の実在・動作までは保証しない。セッションが不明でも `auto` 自体は契約エラーにしない。**`terminal.enable` は端末 Provider の有効化であり、GUI 用 `fileChooser.mode = "terminal"` を暗黙に要求しない。**
- **明示選択:** `mode = "terminal"` は Linux で `termfilechooser`、`mode = "system"` は Linux で GTK、Darwin で OS 標準機構を要求する。対応 Provider と必要な依存がなければ理由付きエラー。Linux では選択したセッション固有ファイルに適用し、実効 backend を検証する。共通 `portals.conf` のみではユーザー側のセッション固有ファイルに負け得るため、実効セッションまたは明示的なセッション固有適用先が不明なら **`terminal`・`system` のどちらも**理由付き契約エラーとし、設定方法を案内する。
- **ポリシーの合成:** セッション固有のファイルを新設すると共通 `portals.conf` は同じ設定ディレクトリ内で選ばれなくなり得る。明示要求によりファイルを生成する場合、既存の **Host 明示ポリシー**（例: `Access=none`、`secretBackend`）を選択セッションの実効ファイルにも反映し、共通ファイルは他セッション向けに維持する。`default`・`Inhibit` 等を無条件にコピー・上書きしない。dotfiles 管理外の既存ファイルを安全に統合できない場合は所有権競合として検出し、無言で置換しない。
- **競合と旧設定:** 有効な `sessionGui.session = "niri"` と明示 `portal.configName = "sway"` のように適用先が矛盾する場合は、黙ってどちらかを優先せず理由付き移行エラーとする。独立 Home で `sessionGui` 無効なら明示 `portal.configName` を尊重する。`portal.configName = "common"` と `secretBackend` 等の明示設定は従来のポリシー／出力先を維持するか、同等の移行先を示す。明示 `terminal`・`system` を同時に保証したい場合は適切なセッション固有適用先を別途要求する。`fileChooser.enable = false` は FileChooser に一切寄与せず、外部 chooser を妨げない。

### Portal の所有者と GUI / TTY 境界

**Portal Service / Backend Provider / Session Provider / Portal Policy Composition は別責務**とする。Portal 本体の有効化は実装・管理者（NixOS、セッション、明示 Home）に属し、FileChooser backend の提供・選択と独立する。Linux の NixOS 管理ホストでは NixOS／セッションが Portal 本体と基本 backend を所有でき、Home Manager はユーザー固有ポリシーや明示的な端末ラッパーを提供できる。全 compositor 共通の Provider Framework を新設する意味ではない。

- **Home 単体・NixOS 単体の双方:** `auto` で選択 backend がなく、他のモジュール・Host からも Portal backend が供給されない場合、desktopIntegration は `xdg.portal.enable = true` を無条件に要求しない。`enable = true` と `extraPortals = []` の組合せを自ら作らず、欠けたパッケージを補わずに最終の Home Manager / NixOS assertion が成立することを保証する。別の所有者が Portal を有効化する場合はその実効設定を尊重する。端末 chooser を明示要求するときだけ必要な backend と、GUI 側のラッパーを組み合わせる。
- **ユーザーポリシーの生成はサービス有効化と独立:** NixOS が Portal 本体を管理し、Home Manager の `xdg.portal.enable` を無効にしても、Home の明示ポリシー（例: Niri の `Secret=none`）は **`xdg.configFile` 等の独立した出力経路**で実際の `~/.config/xdg-desktop-portal/niri-portals.conf` に生成・配置する。Home Manager の `xdg.portal.config` に値があるだけでは達成とみなさない。Home Manager 自身が Portal を管理する構成では二重生成を避け、**1ファイル1所有者**でポリシーを合成する。設定を生成しただけで NixOS の Portal 本体や backend を起動したことにはしない。
- **実効値を保証する範囲:** `auto` は **FileChooser の選択だけ**をセッションへ委譲する。Host が明示した `Access` / `Secret` 等の非 FileChooser ポリシーは委譲・破棄しない。ユーザーとシステムの Portal 設定探索順を考慮し、ユーザー側 `Secret=none` がシステム側 `Secret=gnome-keyring` に対して実効値となること、同時に下位の `Inhibit=none` など無関係なセッションポリシーを破壊しないことを保証・検証する。管理外設定を安全に統合できないときは競合を明示する。

**TTY の Media / Terminal 有効化だけでは GUI の XDG Portal・FileChooser・termfilechooser を要求しない。** `termfilechooser` は TTY 上で動く FileChooser ではなく、GUI アプリのファイル選択を端末エミュレーター＋TUI ファイルマネージャーで実現する Portal backend。GUI で `mode = "terminal"` を明示した場合に限り、Terminal Provider・ファイルマネージャー・ラッパーと実効 Portal 選択を構成する。

**NixOS と Home Manager の整合性:** 管理対象 GUI の `auto` 移行では、NixOS 側の暗黙の `termfilechooser` 強制と Home 側のラッパー撤去を同時に扱う。独立 NixOS の backend 不在時の assertion と、内包 Home の Portal ポリシーファイルの実出力は別々にテストする。NixOS／セッションの既定を使うなら双方から暗黙の強制を除く。端末 chooser を維持する Host は `mode = "terminal"` を明示し、NixOS の backend と Home のラッパーが一致することを保証する。システムと Home の評価を個別に通すだけでは十分ではない。

### FileChooser の選択優先順位と移行

**新 API の `auto` は「backend 自動選択」ではなく「既定への委譲」。** `mode = "system"` は Linux では GTK を明示要求するものとして扱う。旧 API が残る Phase 2 は、Host の明示 `portal.fileChooser.backend = "gtk"` / `"termfilechooser"` / `null` を自動既定より優先し、`null` は chooser 選択・追加パッケージ・ラッパーを提供しない。旧オプションの未指定時だけを委譲型の新 `auto` に切り替えるのは、従来の既定 `termfilechooser` からの**意図的な動作変更**としてテストと移行説明に明記する。Phase 3 では `backend = null` を `fileChooser.enable = false` に移す。

## 機能別の不変条件

1. **Browser:** Glide の既定選択は **GUI Profile が明示的に採用する場合**（Linux GUI、Phase 4 後の Darwin GUI）、または **GUI の Media が要求する場合**に限る（Media は `desktopIntegration.browser.selected = lib.mkDefault "glide"` を要求）。**GUI Profile も Media もない desktopIntegration 単独構成では `selected` の既定は `null`** とし、Browser を導入せず関連付けも生成しない。既存の Qutebrowser 単独構成では `browser.selected = "qutebrowser"`、Glide 単独または Glide + Qutebrowser 構成では `browser.selected = "glide"` に明示的に移行し、従来の Browser 4関連付けを維持する。Host の明示的な `null` や別 Provider は優先する。選択 Provider の最終値から実体と起動コマンドを導出する。Niri の自動起動は desktopIntegration 有効かつ選択ありのときのみ寄与し、Niri 単独構成は壊さない。
2. **Web Playback:** GUI で **選択 Browser・対応 adapter・実効 mpv が揃えば**既定 ON、いずれかがなければ既定 OFF。明示 ON なのに欠ける場合は契約エラー。`media.mpv.enable = false` でも独立した mpv Program が提供されれば既定 ON にできる。実行ファイルは `config.programs.mpv.finalPackage` から導出し、スクリプトを含む最終ラッパーを使う。Firefox の新規プロファイルでは ff2mpv 拡張が実際に有効化され、ブラウザーから送信できることまで保証する。Qutebrowser は **Linux と Darwin の両方**で選択時に既存の `,m` 操作から現在の URL を最終 mpv に渡せることを保証する（その OS での Browser 実装が提供可能なことを前提とし、未対応なら黙って構成しない）。選択変更・無効化後は Media 由来の拡張・native host・キー割り当てを残さない。
3. **File associations:** `desktopIntegration.fileAssociations` は Browser の HTML・XHTML・HTTP・HTTPS と独立したファイル関連付けを扱い、`media.fileAssociations` はメディア関連付けを直接管理する。新 API は既定で部分上書きを合成するが、**`fileAssociations.autoDefaults.enable = false` と明示規則の組合せで自動規則を全停止**できる。この場合 Browser 4件の自動関連付け保証も停止する。自動規則が有効なら選択 Browser と矛盾する最終値を検出する。旧 `mimeApps.defaultApplications` の明示値は *desktopIntegration の寄与を* 全置換するが、Media 等の独立した MIME 寄与は停止しない。無断で新 API の部分上書きへ変換しない。
4. **実効関連付け:** Linux adapter は既存の `video/*`・`audio/*`・`image/*` を維持し、Home Manager による具体 MIME 型への展開を利用する。`video/mp4` に mpv 固定の別規則を重複追加しない。動画の論理ハンドラーを変更したら `video/mp4` の実効値も追従すること、競合するシステム側既定値がある状態でも選択結果が正しいことを照会する。実効 mpv と `mpv.desktop` の存在は別々に検証する。Darwin adapter は OS の関連付け機構を使用する。
5. **FileChooser:** `fileChooser.enable = true` では `mode = auto | system | terminal` を公開する。**`auto` はセッション／OS 既定に委譲し、backend を選択・配置・強制しない**。Terminal が利用可能でも TUI FileChooser を選ばず、Terminal のない Media-only GUI Home と backend 不在の NixOS 単独構成でも全 assertion が通るよう、他の backend がない場合に Portal 本体の有効化まで暗黙に要求しない。明示 `terminal` / `system` は Session Provider と Portal Composition が解決し、最終的な backend の選択と既存明示ポリシーの保持を検証する。セッション不明の共通ファイルへの追記だけでは明示選択の保証としない。**`fileChooser.enable = false` は chooser の選択・パッケージ・専用設定だけを停止**し、他の Portal 設定と外部 chooser を維持する。
6. **Org Protocol:** URL 処理は目的ベースの `orgProtocol.enable` で選択し、OS 固有の登録方法は内部に隠す。Darwin では対応 adapter ができるまで既定 OFF、明示 ON は理由付き契約エラー。Linux の `xdg.desktopEntries.org-protocol` を Darwin に出力しない。
7. **依存・無効化:** GUI で Media が有効なら desktopIntegration を `mkDefault true` で要求する（Darwin への適用は Phase 4）。TTY では要求しない。Feature／子機能の OFF は自身の寄与だけを停止し、共有 Program を排他的に停止しない。Host の上書き後の実効構成が公開契約に反する場合はエラーとし、黙って無視しない。

## 既定動作と実装可能性

GUI では Browser = Glide、Web Playback = ON、mpv = ON を維持する。Linux GUI では Krita を `media.graphics.krita.enable` から要求し、関連付けも有効にする。TTY では CLI と mpv を維持し、Web Playback・Krita・Media 関連付け・GUI 用 Portal／FileChooser は既定 OFF（TTY MIME は既存動作からの意図的変更）。

**機能の既定 ON は、選択 Browser と実効 mpv など必要な実装が揃う場合に限る。** 未実装の機能を別 OS で黙って無視せず、明示 ON は契約エラーにする。Darwin の関連付けなど未提供の機能は、実装が完成するまで保証しない。実装差異を Host の公開設定へ漏らして埋め合わせることもしない。

## 移行保証

Phase 2・3 は Linux の提供経路を Home Manager と NixOS の両側で整合させて切り替え、Darwin の既存 Glide・ff2mpv を維持する。Phase 4 は Darwin GUI の Glide／Web Playback の同等性（**2ホスト×2テーマ＝4 Home 構成**の `Glide.app`、選択プロファイルの ff2mpv 拡張、manifest の `allowed_extensions` と拡張 ID の一致、Browser 連携から最終 mpv への URL 到達）を確認してから旧経路を撤去する。macOS 実機の起動確認は別途必要。

旧 `desktopIntegration.mimeApps.defaultApplications` の全置換動作は Phase 2 まで維持する。Phase 3 では同一結果になる `fileAssociations.autoDefaults.enable = false` と明示規則への移行を案内し、明示的な旧設定は黙って意味を変更せずエラーにする。旧 `media.mimeApps`・`desktopIntegration.portal.fileChooser.backend` 等も、機能 API への移行先または実装固有設定の継続先を示す。とくに FileChooser の旧既定（termfilechooser 強制）から新 `auto`（委譲）への変化と、明示 `backend = "gtk"` / `"termfilechooser"` / `null` の移行結果を区別して記録する。

**非目標:** 共通 Provider Framework、Player Provider、MIME 委譲 API、Home Manager と NixOS の自動同期。
