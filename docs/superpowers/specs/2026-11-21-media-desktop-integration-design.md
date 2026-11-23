# Media / desktopIntegration / fileAssociations リファクタリング設計

**状態:** Draft  
**基準:** [Feature API と内部 Composition](./2026-11-10-feature-capability-provider-contract-design.md)

## 責務と公開 API

Feature は **目的・振る舞い**を公開し、Linux / Darwin の実装差異は内部 Composition が吸収する。OS は公開 API の分類軸ではなく、Provider が契約を満たせるかの判定条件とする。

| Component / API                                    | 契約                                                        |
| -------------------------------------------------- | --------------------------------------------------------- |
| `media`                                            | 再生・制作・CLI・Web Playback の提供。ファイル関連付けは書き込まない                |
| `media.mpv.enable` / `media.graphics.krita.enable` | Media から各 Program を要求                                     |
| `media.cli.{enable,packages}`                      | CLI ツール群を構成                                               |
| `media.webPlayback.enable`                         | 選択 Browser から mpv へ再生 URL を渡す                             |
| `fileAssociations.{enable,handlers,linux.mime}`    | 唯一の関連付け設定入口。論理 Provider 選択と OS 固有の詳細規則を受け付ける            |
| `desktopIntegration.browser.selected`              | Browser Provider を選択（`null` 可）                            |
| `fileAssociations.autoDefaults.*`                  | Media / Browser 等の実効状態に基づく自動既定の有効化と範囲を管理               |
| `desktopIntegration.fileChooser.{enable,mode}`     | GUI アプリの FileChooser を委譲・明示選択する（TTY のファイル操作とは別）           |
| `desktopIntegration.orgProtocol.enable`            | Emacs による org-protocol URL 処理を要求                          |
| `sessionGui.session`                               | dotfiles が提供する GUI セッション設定の選択（識別そのものとは分離）                 |
| 内部 `desktopSession.id`                             | 実効セッション識別（`niri` / `sway` / `null`）、Portal adapter 等が参照   |
| `dotfiles.programs.mpv.*`                          | mpv の独立した提供と固有設定                                          |

`fileAssociations` は **Media・desktopIntegration と別の Feature** とし、関連付けの公開ポリシー・最終合成・OS 出力の所有者を一本化する。`media.fileAssociations.*` と `desktopIntegration.fileAssociations.*` は新規公開しない。公開 API は `fileAssociations.handlers`（`video` / `audio` / `image` / `browser` / `directory` 等の論理ハンドラー）と、同じ Feature 内の `fileAssociations.linux.mime`（任意 MIME 型・Desktop ID・候補の順序付きリスト）に分ける。これは **独立した設定入口を増やすのではなく、一つの Feature に便利 API と高度な指定を収める**ための区別であり、各 API の具体的な型・名称は実装前に確定する。Linux では値を Home Manager の `xdg.mimeApps.defaultApplications` に変換して書き込み、ワイルドカード展開・個別 MIME 優先・候補順の処理を再実装しない。Host の既存 `xdg.mimeApps.defaultApplications` 直接指定は移行期間だけ競合を検出して扱い、最終設計では fileAssociations に移して二重の設定入口として常用しない。

**依存:** Media は従来どおり GUI の Web Playback 等で desktopIntegration / Browser Provider を必要とするが、**fileAssociations は Media も desktopIntegration も有効化を必須としない**。fileAssociations は Media の有効状態と提供済み Program、desktopIntegration の実効 Browser 選択を **読み取り専用の既定値入力**として参照する。Media / desktopIntegration から `fileAssociations.enable = lib.mkDefault true` を要求できるのは GUI の既定関連付けを提供したい場合に限り、Host の `false` を尊重する。fileAssociations から逆方向へ要求する場合は **mpv・Krita・Glide・Yazi 等の個別 Program Provider** だけを `lib.mkDefault true` で要求し、Media / desktopIntegration **Feature 全体**を起動しない。自動既定を決めるために自分が要求した後の実効 Program を判定し直す循環は作らず、明示選択による要求と既存 Provider 状態に基づく自動既定を区別する。最終 `false` で明示要求を満たせない場合は理由付き契約エラー。XDG Portal は汎用 FileChooser と同義ではなく、Linux の実装固有設定として残す。

### 独立 Feature としての関連付けの境界

`fileAssociations.enable = false` は **関連付けの全出力だけを停止**し、Media・Browser・Portal・個別 Program の提供は停止しない。逆に Media または desktopIntegration が OFF でも、Host は fileAssociations 単独で論理ハンドラーや任意の MIME 規則を選択できる。Media は mpv/Krita 等の機能、desktopIntegration は Browser 選択・FileChooser・Org Protocol を担当し、どちらも `xdg.mimeApps` / Darwin の既定アプリ設定へ直接書き込まない（Phase 2 の旧経路は移行中のみ維持）。自動関連付けは fileAssociations Composition が外部の実効状態から一度だけ生成する。

**合成の境界:** `handlers` は便利な論理既定、`linux.mime` は具体 MIME の明示ポリシーとする。後者が同じ具体 MIME 型を指定したときはそれを優先する。ワイルドカードと個別 MIME は異なるキーなので、Home Manager の展開結果では個別 MIME が優先する（例: Host `text/*` と Browser の `text/html`）。同一キーに複数の明示指定が存在する場合は、所有者を一元化して一つの順序付き候補へ解決するか理由付き競合エラーにし、暗黙のリスト連結順に依存しない。任意 Desktop ID を指定しても未知の Program を推測して有効化しない。

**互換性:** 旧 Media / desktopIntegration の合成結果は、例外として明示した振る舞い変更を除き、実効 `mimeapps.list` の各 MIME 型と **候補順**で比較する。Media と desktopIntegration がともに `video/*` を寄与する旧構成では `video/webm = [ "mpv.desktop" "first.desktop" "second.desktop" ]` と `video/mp4 = [ "special.desktop" ]` を維持する。旧 Media 側の全置換で自動既定を消していた場合は新 Feature の `autoDefaults` を対象カテゴリで抑止し、音声・動画等が無断で復活しないようにする。Yazi が未提供でも `inode/directory` / `text/uri-list` に `yazi.desktop` を出す旧動作を「提供済み Program のみ」の原則で変える場合は **意図的な互換性変更**として明記する。

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

**NixOS と Home Manager の整合性:** 管理対象 GUI の `auto` 移行では、NixOS 側の暗黙の `termfilechooser` 強制と Home 側のラッパー撤去を同時に扱う。独立 NixOS の backend 不在時の assertion と、内包 Home の Portal ポリシーファイルの実出力は別々にテストする。NixOS／セッションの既定を使うなら双方から暗黙の強制を除く。端末 chooser を維持する Host は `mode = "terminal"` を明示し、NixOS の backend と Home のラッパーが一致することを保証する。**ただし NixOS 単体で明示 `terminal` を指定した場合の成功条件は、backend パッケージの供給とシステム側の実効選択まで**とし、Home 側の端末・Yazi ラッパーを要求しない。**NixOS + 内包 Home** では、ラッパーも含めて GUI アプリからのファイル選択完了までを保証する（Phase 2 の旧 `portal.fileChooser.backend = "termfilechooser"` も同じ区別）。システムと Home の評価を個別に通すだけでは十分ではない。

### FileChooser の選択優先順位と移行

**新 API の `auto` は「backend 自動選択」ではなく「既定への委譲」。** `mode = "system"` は Linux では GTK を明示要求するものとして扱う。旧 API が残る Phase 2 は、Host の明示 `portal.fileChooser.backend = "gtk"` / `"termfilechooser"` / `null` を自動既定より優先し、`null` は chooser 選択・追加パッケージ・ラッパーを提供しない。旧オプションの未指定時だけを委譲型の新 `auto` に切り替えるのは、従来の既定 `termfilechooser` からの**意図的な動作変更**としてテストと移行説明に明記する。Phase 3 では `backend = null` を `fileChooser.enable = false` に移す。

## 機能別の不変条件

1. **Browser:** Glide の既定選択は **GUI Profile が明示的に採用する場合**（Linux GUI、Phase 4 後の Darwin GUI）、または **GUI の Media が要求する場合**に限る（Media は `desktopIntegration.browser.selected = lib.mkDefault "glide"` を要求）。**GUI Profile も Media もない desktopIntegration 単独構成では `selected` の既定は `null`** とし、Browser を導入せず関連付けも生成しない。既存の Qutebrowser 単独構成では `browser.selected = "qutebrowser"`、Glide 単独または Glide + Qutebrowser 構成では `browser.selected = "glide"` に明示的に移行し、従来の Browser 4関連付けを維持する。Host の明示的な `null` や別 Provider は優先する。選択 Provider の最終値から実体と起動コマンドを導出する。Niri の自動起動は desktopIntegration 有効かつ選択ありのときのみ寄与し、Niri 単独構成は壊さない。
2. **Web Playback:** GUI で **選択 Browser・対応 adapter・実効 mpv が揃えば**既定 ON、いずれかがなければ既定 OFF。明示 ON なのに欠ける場合は契約エラー。`media.mpv.enable = false` でも独立した mpv Program が提供されれば既定 ON にできる。実行ファイルは `config.programs.mpv.finalPackage` から導出し、スクリプトを含む最終ラッパーを使う。Firefox の新規プロファイルでは ff2mpv 拡張が実際に有効化され、ブラウザーから送信できることまで保証する。Qutebrowser は **Linux と Darwin の両方**で選択時に既存の `,m` 操作から現在の URL を最終 mpv に渡せることを保証する（その OS での Browser 実装が提供可能なことを前提とし、未対応なら黙って構成しない）。選択変更・無効化後は Media 由来の拡張・native host・キー割り当てを残さない。
3. **File associations:** 独立 `fileAssociations` Feature を唯一の公開設定・書き込み所有者とし、Media / desktopIntegration は Program・Browser の状態を提供するだけで、関連付けファイルを書かない。`handlers` で明示した既知 Provider は個別 Program を `lib.mkDefault true` で要求し、Host の明示 OFF で最終提供できなければ契約エラー。自動既定は Media・Browser 等の実効状態から **fileAssociations Composition が一度だけ**生成する。mpv が不在なら mpv 自動既定はなし、未知の Desktop ID から Program を推測しない。`autoDefaults.enable = false` は自動規則を停止し、カテゴリ単位の停止は旧全置換の移行に使う。`fileAssociations.enable = false` は関連付けだけ停止して Media / desktopIntegration / Program は停止しない。既定 Browser を変更した場合は HTML・XHTML・HTTP・HTTPS の自動関連付けも追従するが、同じ Feature での明示ハンドラー指定は優先される。
4. **実効関連付け:** Linux adapter は独立 Feature 内の論理選択と `linux.mime` の明示規則を単一の `xdg.mimeApps.defaultApplications` に合成し、固定版 Home Manager の `video/*`・`audio/*`・`image/*` 展開、具体 MIME 優先、順序付き候補を再利用する。同じキーでは Nix の上書き優先度、`text/*` と `text/html` のようにキーが異なる場合は展開後の具体 MIME 優先という区別を守る。`video/mp4` に mpv 固定の別規則は生成せず、明示 `video/mp4` があればそれを優先し、ない場合に動画の論理既定へ追従させる。移行時には `video/mp4` だけでなく `video/webm`・音声・画像・ディレクトリの生成結果と候補順を検証する。Darwin adapter は同じ Feature の論理ポリシーを UTI / Bundle ID および URL スキームへ変換し、Launch Services に一度だけ適用する。
5. **FileChooser:** `fileChooser.enable = true` では `mode = auto | system | terminal` を公開する。**`auto` はセッション／OS 既定に委譲し、backend を選択・配置・強制しない**。Terminal が利用可能でも TUI FileChooser を選ばず、Terminal のない Media-only GUI Home と backend 不在の NixOS 単独構成でも全 assertion が通るよう、他の backend がない場合に Portal 本体の有効化まで暗黙に要求しない。明示 `terminal` / `system` は Session Provider と Portal Composition が解決し、最終的な backend の選択と既存明示ポリシーの保持を検証する。セッション不明の共通ファイルへの追記だけでは明示選択の保証としない。**`fileChooser.enable = false` は chooser の選択・パッケージ・専用設定だけを停止**し、他の Portal 設定と外部 chooser を維持する。
6. **Org Protocol:** URL 処理は目的ベースの `orgProtocol.enable` で選択し、OS 固有の登録方法は内部に隠す。Darwin では対応 adapter ができるまで既定 OFF、明示 ON は理由付き契約エラー。Linux の `xdg.desktopEntries.org-protocol` を Darwin に出力しない。
7. **依存・無効化:** GUI で Media が有効なら desktopIntegration を `mkDefault true` で要求する（Darwin への適用は Phase 4）。TTY では要求しない。Feature／子機能の OFF は自身の寄与だけを停止し、共有 Program を排他的に停止しない。Host の上書き後の実効構成が公開契約に反する場合はエラーとし、黙って無視しない。

### Darwin のアプリ登録と既定アプリの所有者

**Darwin の既定アプリは独立 `fileAssociations` Feature の内部 Darwin adapter が一元的に書き込む。** Program（例: Emacs）は `.app` / Bundle ID の提供と Launch Services への**アプリ登録**を担当し、既定アプリの選択は行わない。現行 `nix/modules/home/programs/emacs/darwin-app.nix` の activation にある `duti -s`（`public.plain-text` / `public.source-code` / `public.shell-script`）は Phase 4 の adapter 導入と同時に移し、重複書き込み・実行順依存をなくす。adapter は論理ハンドラーと UTI / Bundle ID を解決して、全既定値を一つの activation 書き込み経路で適用する。Emacs のアプリ登録を維持したまま他のエディターを明示選択でき、再 activation 後の Launch Services 実効値がその選択と一致することを保証する。Browser の既定についても HTML / XHTML の文書型と HTTP / HTTPS の URL スキームを**それぞれ実効照会**し、OS が同意を要求する場合は同意待ち／拒否／適用済みを区別する。Darwin の旧 Emacs 既定設定は移行時に明示的に扱い、無断で別の既定値へ変えない。

## 既定動作と実装可能性

GUI では Browser = Glide、Web Playback = ON、mpv = ON を維持し、fileAssociations の GUI 自動既定は Media / Browser の実効状態から導出する。Linux GUI では Krita を `media.graphics.krita.enable` から要求し、関連付けも有効にする。TTY では CLI と mpv を維持し、Web Playback・Krita・Media 関連付け・GUI 用 Portal／FileChooser は既定 OFF（TTY MIME は既存動作からの意図的変更）。

**機能の既定 ON は、選択 Browser と実効 mpv など必要な実装が揃う場合に限る。** 未実装の機能を別 OS で黙って無視せず、明示 ON は契約エラーにする。Darwin の関連付けなど未提供の機能は、実装が完成するまで保証しない。実装差異を Host の公開設定へ漏らして埋め合わせることもしない。

## 移行保証

Phase 2・3 は Linux の提供経路を Home Manager と NixOS の両側で整合させて切り替え、Darwin の既存 Glide・ff2mpv を維持する。Phase 4 は Darwin GUI の Glide／Web Playback の同等性（**2ホスト×2テーマ＝4 Home 構成**の `Glide.app`、選択プロファイルの ff2mpv 拡張、manifest の `allowed_extensions` と拡張 ID の一致、Browser 連携から最終 mpv への URL 到達）を確認してから旧経路を撤去する。macOS 実機の起動確認は別途必要。

旧 `desktopIntegration.mimeApps.defaultApplications` の全置換動作は Phase 2 まで維持する。Phase 3 では `media.mimeApps`・`desktopIntegration.mimeApps` の双方を **独立 `fileAssociations` の `handlers` / `linux.mime` / `autoDefaults`** に移し、実効 `mimeapps.list` の合成結果を一致させる。Media と desktopIntegration が重複していた `video/*` は、旧合成後の候補順（例: `video/webm = mpv → first → second`）を失わず、`video/mp4 = special` の明示規則を維持する。Media 単体の旧マップ全置換によって抑制されていた自動既定は、該当カテゴリの `autoDefaults` を抑えて復活させない。新 API の細目は **Home Manager の意味論を再利用した単一 Feature 内の明示規則**として移す。移行中に Host が `xdg.mimeApps.defaultApplications` を直接指定済みなら、優先順位を検証して移行案内または競合エラーとし、無言で混ぜない。旧 `media.mimeApps`・`desktopIntegration.portal.fileChooser.backend` 等も、機能 API への移行先または実装固有設定の継続先を示す。とくに FileChooser の旧既定（termfilechooser 強制）から新 `auto`（委譲）への変化と、明示 `backend = "gtk"` / `"termfilechooser"` / `null` の移行結果を区別して記録する。

**非目標:** 共通 Provider Framework、Player Provider、複数 Feature からの MIME 直接書き込み、Home Manager と NixOS の自動同期。
