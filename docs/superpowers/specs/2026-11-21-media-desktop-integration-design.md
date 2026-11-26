# Media / desktopIntegration / fileAssociations リファクタリング設計

**状態:** Draft

**基準:** [Feature API と内部 Composition](./2026-11-10-feature-capability-provider-contract-design.md)

## 設計原則と公開 API

目的ベースの Feature API を公開し、OS 差異は内部 Composition / Provider に閉じ込める。Profile / Host が Feature の組み合わせと既定選択を所有する。他 Feature 全体を暗黙に起動しない。明示要求に必要な個別 Program は `lib.mkDefault true` で要求し、Host の通常優先度の OFF を尊重する。実効提供不能なら理由付き assertion とし、定義衝突や型エラーで隠さない。OFF は自身の寄与のみを停止し、共有 Program や外部の独立寄与を排他的に停止しない。

| API | 責務 |
| --- | --- |
| `media.mpv.enable` / `media.graphics.krita.enable` | 個別 Program の要求 |
| `media.cli.{enable,packages}` | CLI ツール群 |
| `media.webPlayback.enable` | Browser から mpv への URL 転送 |
| `dotfiles.programs.mpv.*` | 独立した mpv 提供と固有設定 |
| `desktopIntegration.browser.selected` | Browser 選択（既定 null） |
| `desktopIntegration.fileChooser.mode` | Home の GUI FileChooser 選択（既定 auto） |
| `desktopIntegration.orgProtocol.enable` | Emacs への URL 処理 |
| `fileAssociations.{enable,handlers,linux.mime,autoDefaults.enable}` | 利用者の既定アプリポリシー |
| `sessionGui.session` | 管理対象 GUI Session Provider の選択 |

GUI Profile は Media・desktopIntegration・fileAssociations を個別に有効化し、Glide、mpv、Linux の Krita、Linux の FileChooser = terminal を既定採用する。選択・有効化の既定要求は Host が上書きできる。Darwin の chooser は auto。TTY Profile は CLI と mpv を採用し、GUI 基盤を要求しない。Profile なしの Media 単独構成も成立させる。

**非目標:** 旧 API の併存・旧副作用の再現、外部セッション対応・識別 API・実行時セッション推測、共通 Provider Framework / Registry、Player Provider、Home / NixOS の自動同期、独自の競合解決・activation 事前検査。上流の Nix module system・Home Manager・OS の意味論を再実装しない。

## Browser と Web Playback

- 選択 Provider の最終値から実体・起動コマンドを導出する。Media 単独では Browser を要求しない。desktopIntegration OFF または selected = null なら実効 Browser 選択なし。独立 Browser Program と fileAssociations の明示選択は維持する。Niri の自動起動は実効選択がある場合だけ寄与する。
- Web Playback の既定 ON は GUI・実効 Browser・対応 adapter・実効 mpv が揃う場合のみ。明示 ON で依存不足なら理由付きエラー。Media の mpv 要求が OFF でも独立 mpv を利用できる。URL はスクリプトを含む `programs.mpv.finalPackage` の実行ファイルへ渡す。
- Firefox 系の新規プロファイルで ff2mpv が実際に有効になり、Browser 操作から URL を転送できること。Qutebrowser の `,m` は Linux / Darwin とも同じ最終 mpv を利用する。OFF / Browser 切替後は Media 由来の拡張・native host・キー割り当てを残さない。
- Program 提供・Web Playback・既定アプリの対応可否は独立して判定する。固定版 Darwin Qutebrowser は .app の文書型・URL スキーム登録情報が不足するため、既定 Browser 関連付けのみ未対応（後述）。

## Session Provider と Portal

`sessionGui` は管理対象 GUI セッションの構成を所有する。Niri 固有 Program は維持し、既存の NixOS `sessions.niri` と Home の Niri 要求を内部 Provider にまとめる。今回は Niri のみ対応する。

| 内部 Provider | 提供情報 |
| --- | --- |
| Home | ユーザー設定・実効提供状態・Portal のセッション固有出力先 |
| NixOS | システム側提供状態・セッション名・起動コマンド・Portal 出力先 |

Greeter / Portal は選択 Provider の情報を参照し、Consumer に Niri 固有条件を分散させない。sessionGui OFF なら実効 Provider なし。独立した Niri Program や既定の session 値から選択を推測しない。NixOS Niri の enable 要求にも共通の既定優先度・assertion 契約を適用する。

### FileChooser

**所有境界:** NixOS / Session Provider が Portal 本体・標準 backend・セッション固有 backend を提供し、Home がユーザー固有 backend・選択・ラッパーを提供する。高水準選択 API は Home のみ。上流 NixOS `xdg.portal.*` は維持する。

| `fileChooser.mode` | 契約 |
| --- | --- |
| auto（既定） | OS / セッション標準へ委譲。chooser 固有の backend・パッケージ・ラッパー・選択キーを寄与せず、実体の存在も保証しない |
| terminal | Linux の termfilechooser を提供・選択。Darwin では理由付き未対応エラー |

Linux GUI Profile は `fileChooser.mode = lib.mkDefault "terminal"` とし、現行の端末 chooser を維持する。Host の auto 上書きは有効。Darwin auto は OS・アプリ標準動作への委譲でありネイティブダイアログを強制しない。Terminal Feature や TTY Media の有効化だけでは chooser を要求しない。

terminal の依存契約:

- 実効 Home Session Provider、ホスト側 Portal Service、選択 Terminal Provider の待機・子コマンド起動経路、Yazi 互換ファイルマネージャーが必要。統合 Home では NixOS 実効 `osConfig.xdg.portal.enable` 等を確認する。独立 Home ではホスト側の本体・起動基盤・標準 backend 提供を前提として文書化する。auto / desktopIntegration OFF ではこれらを要求せず、GTK 固定の依存も設けない。
- 既存 `termfilechooser.fileManager.package` は `programs.yazi.package` を既定とし、互換パッケージの明示指定を尊重する。契約は `bin/yazi` と `--chooser-file` / `--cwd-file` 対応であり、programs.yazi.enable は必須ではない。実効値を nullable として扱い、null なら理由付き assertion、ラッパー生成は非 null の場合だけ行う。
- Home は backend パッケージ・.portal・D-Bus サービス定義・systemd user unit・探索経路・選択キー・Yazi ラッパーを提供する。管理対象 NixOS Home では `xdg.portal.enable = false` を維持し、その extraPortals に依存しない。Portal 本体を重複提供せず、どちらの評価環境でも本体 ON + 空 extraPortals を無条件に作らない。
- 新構成の実効状態は OS 再起動後に保証する。即時反映・独自再読込・自動再起動・個別サービスの手動反映手順は対象外。Home backend の D-Bus / systemd 起動と正しい ExecStart、GUI アプリへのファイル返却を保証するが、OpenFile 直前の停止や特定クライアントによる最初の起動は要求しない。

### Portal ポリシー

FileChooser の選択キーだけを terminal 時に出力し、明示された default / Access / Notification / Secret 等は mode と独立して保持する。未指定ポリシーは生成しない（Secret=none だけなら暗黙 default を追加しない）。`portal.configName` 等は詳細設定の出力先であり、セッション識別 API ではない。高水準 chooser の適用先は Session Provider から導出する。

管理対象ファイルは一つの生成経路へ合成し、上流 Home Portal が OFF でも `xdg.configFile` 等で実ファイルを配置する。共通 portals.conf とセッション固有ファイルは別の入力・出力とし、探索・優先順位・backend 解決は Portal に委譲する。別ファイルへの自動転記・管理外ファイルの統合や置換は行わない。保証は適切に構成した管理対象環境に限定し、任意の外部設定での実効値は保証しない。

## fileAssociations

### 所有と合成

利用者向け既定ポリシーは独立 fileAssociations のみが所有し、Media / desktopIntegration は直接書かない。主 API の handlers は video / audio / image / browser / directory / textEditor 等の論理選択。Linux の `linux.mime` は任意 MIME 型と順序付き Desktop ID 候補を追加・部分上書きする escape hatch とし、型・名称の詳細は実装前に確定する。未知の Desktop ID から Program を推測しない。

明示 handlers → 個別 Program 要求 → Program の実効状態 → 自動既定の順で評価する。自動既定から Program 要求へ逆参照せず、要求元を区別しない。明示 handler は autoDefaults OFF でも適用する。自動既定は GUI で有効な場合に導出し、カテゴリ別停止 API は設けない。

Feature 内の合成は 自動既定 → handlers → linux.mime の同一入力キー単位の右優先置換（候補リストの連結なし）。Linux adapter は一つの `xdg.mimeApps.defaultApplications` 寄与へ変換する。Nix が定義合成、Home Manager がワイルドカード展開・具体 MIME 優先・候補順・mimeapps.list 生成、OS / XDG が実効解決を担当する。

Program 固有 MimeType・専用スキーム（Radicle 等）の既定寄与と `xdg.mimeApps.defaultApplicationPackages` は共存可能。後者は明示候補の末尾にパッケージ由来候補を追加し、未指定型も補完する upstream の契約に従う。fileAssociations OFF / autoDefaults OFF は外部寄与を停止しない。fileAssociations OFF では自身の出力要求だけを停止し、共有 `xdg.mimeApps.enable` を強制 OFF にしない。外部設定値の存在と実ファイル生成は別である。

### 提供契約と自動既定

| handler | Linux の提供条件・対応範囲 |
| --- | --- |
| video / audio / image | 実効 mpv と対応 MIME 型（下記） |
| browser | 実効 Browser 選択から HTML / XHTML / HTTP / HTTPS |
| directory | 実効 Yazi と GUI 端末起動経路から inode/directory / text/uri-list |
| textEditor | Emacs Program・サービス・client・Server 起動経路と emacsclient.desktop から text/plain |
| org-protocol | desktopIntegration / orgProtocol の実効有効化と URL 処理契約（次節） |

**mpv:** Linux は bin/mpv と mpv.desktop、Darwin は実行ファイルと動画・音声対応 .app / Bundle ID を提供する。最終 Program OFF / package null は未提供（自動既定なし、明示要求エラー）。GUI の自動既定は最終提供状態に従い、例えば明示 video 要求で mpv が提供されれば対応する audio / image にも波及する。自動既定 OFF または明示選択で制御する。

標準・スクリプト付きラッパー・明示カスタム・overlay を区別せず非 null の提供契約を信頼する。パッケージ提供者が登録情報・起動動作を維持し、管理対象標準構成はビルド時と Nixpkgs 更新時に検証する。評価時 pathExists / IFD・由来追跡・専用メタデータや宣言 API・Consumer による登録補完は導入しない。mpv.desktop を欠く CLI 専用差し替えは契約外であり、fileAssociations OFF だけで整合する保証はない。変更者が整合性を管理する。

Linux では mpv Program が `xdg.mimeApps.associations.added` で確認済み画像型（最低 PNG / JPEG）を追加登録し、必要な共有出力を要求できる。fileAssociations は既定選択のみを所有する。動画・音声は標準 Desktop Entry、画像は追加登録の有限の対応型集合を明示・自動双方で利用する。未確認の wildcard 全体は対象外。追加登録は fileAssociations / autoDefaults OFF でも独立して維持する。

**Yazi:** Terminal Feature が選択 Terminal Provider の Desktop ID を upstream `xdg.terminal-exec` に渡して GUI の Terminal=true 起動経路を提供する（TTY では要求しない）。directory には実効 Yazi・端末起動経路の両方が必要。enable に加え `programs.yazi.package` / `xdg.terminal-exec.package` の非 null を確認し、Yazi finalPackage は非 null のときのみ参照する。管理対象の実体がなければ自動既定なし・明示要求は理由付きエラー。任意外部実体の探索、Kitty 固定分岐、directory 専用ラッパーは設けない。非 null の互換パッケージは信頼する。

### Emacs / Org Protocol

Linux の Org Protocol と textEditor は Emacs Program の同じ内部 Server 提供条件を参照する。管理対象の新規セッションではサービス有効に加え socket activation またはユーザーセッション起動が必要。両方 OFF ならサービス・client ON でも未提供とする。既存の Server / Org Protocol ロードを利用し、新しい Server 管理機構は導入しない。

Org Protocol は URL 処理可能な場合だけ既定 ON とし、明示 ON で依存不足はエラー。Desktop Entry の存在だけでは成功としない。textEditor の明示選択も上表の条件を要求し、満たさなければエラー。Darwin の Org Protocol は既定 OFF・明示 ON は理由付き未対応エラー、XDG Desktop Entry は生成しない。

### Darwin の関連付け

Program は .app / Bundle ID と Launch Services のアプリ登録を所有し、独立 fileAssociations の Darwin adapter が UTI・URL スキームの既定設定を一度の activation 経路で適用する。XDG MIME を流用しない。

| handler | 対応 |
| --- | --- |
| textEditor = emacs | 明示選択で public.plain-text / public.source-code / public.shell-script |
| video / audio = mpv | 自動・明示で public.movie / public.video、public.audio |
| image = mpv | 未対応（自動除外・明示エラー） |
| browser | 対応 Provider の HTML / XHTML / HTTP / HTTPS。Qutebrowser は自動除外・明示エラー |

Emacs の registerEmacsApp は登録のみに限定し、旧 duti -s を adapter へ移す。Emacs 単独では既定設定を要求しない。新規ユーザーで fileAssociations OFF / 未指定なら旧既定を再現せず、既存 OS 設定も無条件消去しない。DAG は copyApps → registerEmacsApp → 既定設定とし、他選択 Provider の登録完了も必要。

Browser・Emacs・mpv の初回 activation における変更要求と、OS 同意が必要な場合の承認後の実効照会を区別する。利用者の承認を正常系とし、未承認・拒否は成功ではない。独自の状態管理・再試行は設けない。

Neovim は将来候補（Neovide 等の実装・本番選択肢は範囲外）。Darwin mpv の画像 Info.plist 補完や Qutebrowser の登録情報補完は行わない。将来の修正は Nixpkgs、必要なら Program の package override を優先する。未対応の関連付けが Program 提供や Web Playback を妨げてはならない。

## 移行と完了条件

旧設定を新 API に直接移し、意図的な変更を記録する。旧 MIME マップ全置換・旧候補順の完全再現は要求しない。各 Phase の管理対象構成を成立させる。具体的な移行順・検証は [実装計画](../plans/2026-11-21-media-desktop-integration-refactor.md) を正とする。
