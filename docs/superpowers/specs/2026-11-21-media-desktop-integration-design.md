# Media / desktopIntegration / fileAssociations リファクタリング設計

**状態:** Draft

**基準:** [Feature API と内部 Composition](./2026-11-10-feature-capability-provider-contract-design.md)

## 設計原則

責務の明確さ・依存関係・目的ベースの API・上流の意味論への委譲を優先する。旧実装との完全な動作互換は不変条件としない。管理対象の設定を新 API へ移行し、意図的な変更と移行先を記録する。旧 API の併存や旧副作用の再現だけを目的とする互換レイヤー・分岐・テストは設けない。ただし、新 API の明示要求を満たすこと、各 Phase の構成が成立すること、独立した設定や Program の提供を破壊しないことは引き続き保証する。

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

`fileAssociations` は **Media・desktopIntegration と別の Feature** とし、利用者が選択する既定アプリのポリシーの所有者を一本化する。Home Manager の生成処理や Program 固有の対応形式・専用スキームの提供は独占しない。`media.fileAssociations.*` と `desktopIntegration.fileAssociations.*` は新規公開しない。主 API は `fileAssociations.handlers`（`video` / `audio` / `image` / `browser` / `directory` 等の論理ハンドラー）とし、OS 差異の吸収、Provider 要求、複数の型・スキームの一括設定に価値がある目的ベースの抽象化を提供する。全 MIME 型を別名として網羅しない。同じ Feature 内の `fileAssociations.linux.mime`（任意 MIME 型・Desktop ID・候補の順序付きリスト）は抽象 API で扱わない規則の追加と部分上書きの Escape Hatch とする。具体的な型・名称は実装前に確定する。Linux では値を Home Manager の `xdg.mimeApps.defaultApplications` に変換して書き込み、ワイルドカード展開・個別 MIME 優先・候補順の処理を再実装しない。管理対象 Host の既存の利用者向け `xdg.mimeApps.defaultApplications` 直接指定は fileAssociations に移し、二重の公開入口として常用しない。移行のための独自競合解決器や旧合成結果の再現処理は設けない。ただし Program 固有の寄与および `xdg.mimeApps.defaultApplicationPackages` は下記の所有境界に従って共存できる。

**依存:** Profile / Host が利用環境に応じた Feature の組み合わせと既定選択を所有する。GUI Profile は Media・desktopIntegration・fileAssociations を個別に有効化し、Browser 選択等を `lib.mkDefault` で設定する。Media / desktopIntegration から他 Feature 全体を暗黙に有効化したり、Media の有効化だけで Browser を要求したりしない。Feature は自らの明示された機能に必要な個別 Program Provider を要求できる。Web Playback は選択 Browser・対応 adapter・実効 mpv を参照し、明示 ON で不足する依存は理由付きエラーとする。fileAssociations は Media / desktopIntegration の有効化を必須とせず、Program の最終提供状態と利用可能な Browser 選択を読み取り専用の既定値入力とする。明示 `handlers` は mpv・Krita・Glide・Yazi 等の個別 Program Provider を `lib.mkDefault true` で要求し、Feature 全体を起動しない。**明示選択による Program 要求 → Program の最終提供状態 → 自動既定の導出** の順で評価し、自動既定から Program 要求への逆参照や要求元の追跡を作らない。Provider は Consumer の要求を満たす有効化経路を提供し、Host の明示 OFF を強制上書きせず、要求を満たせなければ理由付き契約エラーとする。

### 独立 Feature としての関連付けの境界

`fileAssociations.enable = false` は **自身の関連付けポリシー・要求・出力だけを停止**し、Media・Browser・Portal・個別 Program の独立した提供や外部の MIME / 専用スキーム寄与を停止しない。逆に Media または desktopIntegration が OFF でも、Host は fileAssociations 単独で論理ハンドラーや任意の MIME 規則を選択できる。Media は mpv/Krita 等の機能、desktopIntegration は Browser 選択・FileChooser・Org Protocol を担当し、どちらも `xdg.mimeApps` / Darwin の既定アプリ設定へ直接書き込まない（関連付けの所有者は Phase 3 で一括して切り替える）。自動関連付けは fileAssociations Composition が Program の最終提供状態と Browser 選択等から一度だけ生成する。

**合成の境界:** fileAssociations 内部では、自動既定を明示 `handlers` が上書きし、論理ハンドラーから変換した Linux 規則を `linux.mime` が同一入力キー単位で置換・補完する（属性集合の右優先合成 `//` に相当）。同一キーの候補リストを暗黙に連結せず、Feature 内で一つの規則に決めてから Home Manager に渡す。例えば `handlers.browser = "glide"` と `linux.mime."text/html" = [ "reader.desktop" "fallback.desktop" ]` の併用では HTML の候補は reader → fallback、XHTML・HTTP・HTTPS は Glide とする。設定寄与後の定義合成は Nix module system、ワイルドカード展開・候補合成・ファイル生成は Home Manager、実効ハンドラー解決は OS / XDG 実装に委譲する。展開後の MIME に独自優先順位を設けない。任意 Desktop ID から未知の Program を推測して有効化しない。

**所有境界:** fileAssociations は利用者向け既定ポリシーの決定者であり、Home Manager の `mimeapps.list` 生成そのものを置き換えない。Program は `.desktop` の `MimeType` や自身の専用 URL スキーム（例: Radicle）を登録し、その Program 固有のスキームの既定寄与も許容する。外部 Program の規則との合成は Nix module system と Home Manager の既存の意味論に従い、無関係なキーを削除しない。管理対象 Host の利用者ポリシーは新 API に移行するが、他 Program の対応形式・専用スキームを一律に競合扱いしない。固定版 Home Manager の `xdg.mimeApps.defaultApplicationPackages` は許容し、展開済み `defaultApplications` の順序付き候補を先に、パッケージ由来候補を末尾に追加する upstream の意味論を維持する。指定のない MIME 型がパッケージにより追加されることも許容する。例えば `text/html=chosen.desktop;from-package.desktop` と `application/pdf=from-package.desktop` が生成されることを検証する。`autoDefaults.enable = false` も外部の独立寄与を止める指定ではない。fileAssociations OFF は共有の `xdg.mimeApps.enable` を強制 OFF にせず、自らは出力機能を要求しない。外部の設定値が残ることとファイル生成は別の契約であり、外部 Consumer または Host が出力を要求した場合に Home Manager が生成する。

**自動既定の入力:** GUI で fileAssociations と対象カテゴリの自動既定が有効、他の明示規則や競合候補がなく、mpv が実効 Desktop Entry を提供する場合は `video/*`・`audio/*`・`image/*` の自動既定に mpv を使う。`media.mpv.enable = false` でも、`handlers.video = "mpv"` からの要求で最終 Program が ON になれば、動画は明示 mpv、音声・画像は自動 mpv となる。別途 mpv Program を ON にした場合は3カテゴリとも自動 mpv、最終 OFF または Desktop Entry 不在なら3カテゴリとも mpv 自動既定なし。`handlers.video` の指定は Program 提供を通じて他の自動既定に波及し得る。要求元の区別でこれを抑止せず、カテゴリ単位の明示規則や自動既定停止で調整する。Emacs の `org-protocol` は desktopIntegration と orgProtocol の実効有効化およびハンドラー提供が成立するときだけ自動選択し、`text/plain` は Emacs サービスと client の双方が有効で Desktop Entry が提供されるときだけ自動選択する。

**互換性:** 旧 Media / desktopIntegration の MIME マップ全置換や複数 Feature の暗黙の候補リスト連結は再現しない。新 API の明示候補順・部分上書き・自動既定の契約を検証する。旧 Host の意図的な規則は新 API で記述できるようにし、未提供 Yazi の自動関連付け廃止等の動作変更を移行案内に記録する。

## Desktop Session の識別と Portal の適用先

**セッション識別、セッション設定の提供、FileChooser 選択、Portal 設定の合成を別責務にする。** `sessionGui` は Niri 等の dotfiles 管理設定を提供し、内部の実効 `desktopSession.id`（`niri` / `sway` / `null`）は対象セッションの識別だけを表す。desktopIntegration はその実効値を参照し、セッションの管理・起動自体は要求しない。全 compositor 共通の Provider Framework は作らない。

- **識別元:** 有効な `sessionGui` の管理対象または Host の明示セッション文脈から実効 ID を導出する。無効な `sessionGui` の既定値を実セッションとみなさず、任意の実行時 `XDG_CURRENT_DESKTOP` を評価時に推測しない。セッションの識別と管理・起動は独立とする。Linux 固有の `portal.configName` は直接の設定出力先であり、セッション識別の情報源にはしない。
- **Session Provider:** 既知のセッション ID から高水準 FileChooser の設定出力先を導出する。FileChooser Provider は backend の実体と必要な依存を提供する。Portal Composition は dotfiles が同一ファイルに寄与する設定を合成するだけで、別ファイル間の探索・解決を行わない。
- **`fileChooser.mode = "auto"`:** セッション／OS の既定動作に委譲する。**FileChooser の backend 選択・追加 backend パッケージ・専用ラッパー・強制設定を desktopIntegration から寄与しない。** Terminal の有無により自動的に `termfilechooser` / `gtk` を選んで書き込む旧案は撤回する。Session Provider / OS の既存設定を尊重し、未構成環境で chooser の実在・動作までは保証しない。セッションが不明でも `auto` 自体は契約エラーにしない。**`terminal.enable` は端末 Provider の有効化であり、GUI 用 `fileChooser.mode = "terminal"` を暗黙に要求しない。**
- **明示選択:** `mode = "terminal"` は Linux の termfilechooser、`mode = "system"` は Linux の GTK または Darwin の OS 標準機構を構成する。必要な Provider と依存を提供できなければ理由付きエラー。Linux の高水準 API は既知のセッションまたは Host が明示したセッション固有適用先へ設定を寄与し、どちらも不明なら理由付きエラーとする。明示選択の動作確認は適切なセッションと依存を用意した管理対象環境で行い、任意の外部設定に対する優先を保証しない。
- **ポリシーの合成:** dotfiles は指定された出力先に設定を提供し、同一の管理対象ファイルへの寄与は一つの生成経路に合成する。共通 `portals.conf` とセッション固有ファイルは独立した入力・出力先とし、ファイル間の探索順、優先順位、backend 解決は xdg-desktop-portal の意味論に委譲する。共通設定が固有設定に隠れても自動転記・補完しない。管理外ファイルの探索・読み取り・統合や、隠蔽を検出する独自 activation 検査は設けない。管理対象ファイルの衝突は通常の Nix / Home Manager の仕組みで扱い、管理外ファイルを独自に置換しない。
- **適用先:** `portal.configName` や `secretBackend` 等は Linux 固有の詳細設定として扱い、指定された共通または固有ファイルへ寄与する。高水準 FileChooser の適用先とは独立に指定できるため、別セッション向け設定が存在するだけでは競合としない。Host / Profile が必要な出力先にポリシーを明示する。`fileChooser.enable = false` は FileChooser の寄与だけを停止する。

### Portal の所有者と GUI / TTY 境界

**Portal Service / Backend Provider / Session Provider / Portal Policy Composition は別責務**とする。Portal 本体の有効化は実装・管理者（NixOS、セッション、明示 Home）に属し、FileChooser backend の提供・選択と独立する。Linux の NixOS 管理ホストでは NixOS／セッションが Portal 本体と基本 backend を所有でき、Home Manager はユーザー固有ポリシーや明示的な端末ラッパーを提供できる。全 compositor 共通の Provider Framework を新設する意味ではない。

- **Home 単体・NixOS 単体の双方:** `auto` で選択 backend がなく、他のモジュール・Host からも Portal backend が供給されない場合、desktopIntegration は `xdg.portal.enable = true` を無条件に要求しない。`enable = true` と `extraPortals = []` の組合せを自ら作らず、欠けたパッケージを補わずに最終の Home Manager / NixOS assertion が成立することを保証する。別の所有者が Portal を有効化する場合はその実効設定を尊重する。端末 chooser を明示要求するときだけ必要な backend と、GUI 側のラッパーを組み合わせる。
- **ユーザーポリシーの生成はサービス有効化と独立:** NixOS が Portal 本体を管理し、Home Manager の `xdg.portal.enable` を無効にしても、Home の明示ポリシー（例: Niri の `Secret=none`）は **`xdg.configFile` 等の独立した出力経路**で実際の `~/.config/xdg-desktop-portal/niri-portals.conf` に生成・配置する。Home Manager の `xdg.portal.config` に値があるだけでは達成とみなさない。Home Manager 自身が Portal を管理する構成では二重生成を避け、**1ファイル1所有者**でポリシーを合成する。設定を生成しただけで NixOS の Portal 本体や backend を起動したことにはしない。
- **実効値を保証する範囲:** `auto` は FileChooser 選択に寄与せず、Host が明示した `Access` / `Secret` 等は指定されたファイルへ出力する。dotfiles は同一管理対象ファイルの無関係なキーを破壊しないが、別ディレクトリ・別ファイルのポリシーを実効値として保持するための独自合成は行わない。管理対象の適切な設定を使用した動作検証と、任意の外部設定に対する実効値の保証を区別する。

**TTY の Media / Terminal 有効化だけでは GUI の XDG Portal・FileChooser・termfilechooser を要求しない。** `termfilechooser` は TTY 上で動く FileChooser ではなく、GUI アプリのファイル選択を端末エミュレーター＋TUI ファイルマネージャーで実現する Portal backend。GUI で `mode = "terminal"` を明示した場合に限り、Terminal Provider・ファイルマネージャー・ラッパーと実効 Portal 選択を構成する。

**NixOS と Home Manager の整合性:** NixOS と Home の FileChooser はそれぞれの管理範囲で明示選択し、暗黙に同期しない。NixOS の `terminal` は backend パッケージの提供とシステム側の実効選択を保証する。内包 Home も `terminal` を明示するか、動作する外部ラッパー・設定があるときに限り、統合環境で GUI アプリからのファイル選択完了を保証する。NixOS が `terminal`、Home が `auto` で外部設定もない場合は NixOS の提供・選択までを合格とし、Home の `auto` を変更せず、ファイル選択完了は保証しない。

### FileChooser API の切替

Phase 2 で新 API に直接切り替え、旧 `portal.fileChooser.backend` と新 API の並行優先順位は設けない。管理対象設定は必要な新 mode へ移行する（旧 `gtk` → `system`、`termfilechooser` → `terminal`、`null` → `enable = false` は移行案内の例）。未指定時の `auto` は既定への委譲とする。旧 API の互換動作は受入条件にしない。

## 機能別の不変条件

1. **Browser:** Glide の既定選択は **GUI Profile / Host が採用する場合**（Linux GUI、Phase 4 後の Darwin GUI）に限る。**Feature 自体の `selected` の既定は `null`** とし、Media の有効化だけでは Browser を導入せず、Browser 関連付けも要求しない。Host / Profile で必要な Browser を選択し、旧 Program フラグの組み合わせから旧 Browser 選択順を再現しない。Host の明示的な `null` や別 Provider は優先する。選択 Provider の最終値から実体と起動コマンドを導出する。Niri の自動起動は desktopIntegration 有効かつ選択ありのときのみ寄与し、Niri 単独構成は壊さない。
2. **Web Playback:** GUI で **選択 Browser・対応 adapter・実効 mpv が揃えば**既定 ON、いずれかがなければ既定 OFF。明示 ON なのに欠ける場合は契約エラー。`media.mpv.enable = false` でも独立した mpv Program が提供されれば既定 ON にできる。実行ファイルは `config.programs.mpv.finalPackage` から導出し、スクリプトを含む最終ラッパーを使う。Firefox の新規プロファイルでは ff2mpv 拡張が実際に有効化され、ブラウザーから送信できることまで保証する。Qutebrowser は **Linux と Darwin の両方**で選択時に既存の `,m` 操作から現在の URL を最終 mpv に渡せることを保証する（その OS での Browser 実装が提供可能なことを前提とし、未対応なら黙って構成しない）。選択変更・無効化後は Media 由来の拡張・native host・キー割り当てを残さない。
3. **File associations:** 独立 `fileAssociations` Feature を利用者向け既定ポリシーの唯一の公開設定所有者とし、Media / desktopIntegration は Program・Browser の状態を提供するだけで、関連付けファイルを書かない。`handlers` で明示した既知 Provider は個別 Program を `lib.mkDefault true` で要求し、Host の明示 OFF で最終提供できなければ契約エラー。自動既定は要求元を問わず最終 Program / Browser の実効提供状態から **fileAssociations Composition が一度だけ**生成する。動画への明示 mpv 要求で Program が提供されれば音声・画像の自動既定にも波及する。mpv が不在なら mpv 自動既定はなし、未知の Desktop ID から Program を推測しない。`autoDefaults.enable = false` は自動規則を停止する。カテゴリ単位の停止を提供するかは独立した利用要件に基づいて決め、旧全置換の再現を理由に必須としない。`fileAssociations.enable = false` は自身の寄与だけ停止して Media / desktopIntegration / Program の独立した提供や関連付け寄与は停止しない。既定 Browser を変更した場合は HTML・XHTML・HTTP・HTTPS の自動関連付けも追従するが、同じ Feature での明示ハンドラー指定は優先される。
4. **実効関連付け:** Linux adapter は独立 Feature 内の論理選択と `linux.mime` の明示規則を単一の `xdg.mimeApps.defaultApplications` への寄与に合成し、外部 Program の非競合規則と `defaultApplicationPackages` の末尾追加を尊重し、固定版 Home Manager の `video/*`・`audio/*`・`image/*` 展開、具体 MIME 優先、順序付き候補を再利用する。同一入力キーの定義合成は Nix、異なる入力キーの展開・解決は Home Manager に委譲する。例えば `video/* = lib.mkForce "chosen.desktop"` と `video/mp4 = lib.mkDefault "external.desktop"` の組合せでも、固定版 Home Manager の展開では WebM が `chosen.desktop`、MP4 が `external.desktop` となる。dotfiles はこの結果を変更しない。`video/mp4` に mpv 固定の別規則は生成しない。新 API の設定寄与、明示候補順と部分上書きを検証する。旧生成物との完全一致は要求しない。Darwin adapter は同じ Feature の論理ポリシーを UTI / Bundle ID および URL スキームへ変換し、Launch Services に一度だけ適用する。
5. **FileChooser:** `fileChooser.enable = true` では `mode = auto | system | terminal` を公開する。**`auto` はセッション／OS 既定に委譲し、backend・パッケージ・ラッパーを寄与しない**。外部 backend がない場合にも Portal 本体の有効化を暗黙に要求しない。明示 `terminal` / `system` は必要な Provider と適用先への設定を提供し、管理対象の適切な環境で動作を検証する。ファイル間の探索・解決は Portal に委譲する。**`fileChooser.enable = false` は chooser の寄与だけを停止**し、他の Portal 設定と外部 chooser を維持する。
6. **Org Protocol:** URL 処理は目的ベースの `orgProtocol.enable` で選択し、OS 固有の登録方法は内部に隠す。Darwin では対応 adapter ができるまで既定 OFF、明示 ON は理由付き契約エラー。Linux の `xdg.desktopEntries.org-protocol` を Darwin に出力しない。
7. **依存・無効化:** GUI / TTY の Feature の組み合わせは Profile / Host が決める。Media や desktopIntegration の有効化だけで別 Feature を要求しない。個別 Program の必要な要求と実効状態の参照は維持する。Feature／子機能の OFF は自身の寄与だけを停止し、共有 Program を排他的に停止しない。Host の上書き後の実効構成が明示された公開契約に反する場合は理由付きエラー。

### Darwin のアプリ登録と既定アプリの所有者

**Darwin の既定アプリは独立 `fileAssociations` Feature の内部 Darwin adapter が一元的に書き込む。** Program（例: Emacs）は `.app` / Bundle ID の提供と Launch Services への**アプリ登録**を担当し、既定アプリの選択は行わない。現行 `nix/modules/home/programs/emacs/darwin-app.nix` の activation にある `duti -s`（`public.plain-text` / `public.source-code` / `public.shell-script`）は Phase 4 の adapter 導入と同時に移し、重複書き込み・実行順依存をなくす。adapter は論理ハンドラーと UTI / Bundle ID を解決して、全既定値を一つの activation 書き込み経路で適用する。Emacs のアプリ登録を維持したまま他のエディターを明示選択でき、再 activation 後の Launch Services 実効値がその選択と一致することを保証する。Browser の既定についても HTML / XHTML の文書型と HTTP / HTTPS の URL スキームを**それぞれ実効照会**し、OS が同意を要求する場合は同意待ち／拒否／適用済みを区別する。Emacs Program 単独では既定アプリを設定せず、fileAssociations の有効化も要求しない。fileAssociations 未指定・無効の新規ユーザーに旧3種の既定設定を再現しない。必要なら Host / Profile の関連付けポリシーで指定する。既存ユーザーの OS に残る設定を無条件に消去しない。

## 既定動作と実装可能性

GUI Profile は Media・desktopIntegration・fileAssociations を組み合わせ、Browser = Glide、mpv = ON、必要な依存が揃う場合の Web Playback、Linux の Krita を既定として構成する。TTY Profile は CLI と mpv を採用し、GUI 用 Feature を暗黙に要求しない。Profile を使わない Media 単独構成では mpv 等の自機能だけを提供する。fileAssociations を独立して有効にした場合は Program の最終提供状態から自動既定を導出する。Host の明示上書きを尊重する。

**機能の既定 ON は、選択 Browser と実効 mpv など必要な実装が揃う場合に限る。** 未実装の機能を別 OS で黙って無視せず、明示 ON は契約エラーにする。Darwin の関連付けなど未提供の機能は、実装が完成するまで保証しない。実装差異を Host の公開設定へ漏らして埋め合わせることもしない。

## 移行と完了条件

Phase 2・3 は Linux の提供経路を Home Manager と NixOS の両側で整合させて切り替える。Darwin の未移行機能は Phase 4 で切り替え、各 Phase 終了時の管理対象構成を成立させる。Phase 4 の Darwin GUI は **2ホスト×2テーマ＝4 Home 構成**のビルドと新契約（アプリの提供、Web Playback の実効パッケージ・拡張と URL 到達）を検証する。macOS 実機の確認は別途必要。旧実装との同等性ではなく新契約を受入条件とする。

旧 `media.mimeApps`・`desktopIntegration.mimeApps` は Phase 3 で独立 `fileAssociations` へ一括移行する。旧 `portal.fileChooser.backend` は Phase 2 で新 FileChooser API へ切り替える。明示設定の移行先と意図的な動作変更を記録し、旧オプションは必要に応じて移行先を示すエラーとする。旧マップ全置換・旧候補順・旧副作用を再現する機構は作らない。

**非目標:** 共通 Provider Framework、Player Provider、複数 Feature による利用者向け既定ポリシーの直接書き込み、Home Manager と NixOS の自動同期。
