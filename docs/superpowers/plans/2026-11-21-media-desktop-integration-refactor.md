# Media / desktopIntegration / fileAssociations リファクタリング実装計画

**前提:** [設計仕様](../specs/2026-11-21-media-desktop-integration-design.md)

**受入方針:** 責務と新 API の契約を優先し、旧動作の完全再現・互換 API の併存は要求しない。各 Phase の管理対象構成は成立させ、意図的な変更と移行先を記録する。

## Phase 1 — mpv の独立化

**対象:** `nix/modules/home/programs/mpv/default.nix`（新規）、`nix/modules/home/features/media.nix`。

- `media.mpv.settings` を Program に移し、`autofit-large` を `autofit-larger` に修正する。旧オプションは移行先を示すエラーにする。
- `programs.mpv.finalPackage` を実効実行ファイルとして扱い、`scripts` や package 上書きも反映する。
- 生成 `mpv.conf` の読み込み結果について、終了コードだけでなく `Error parsing option` を検査する。単独利用と `package = null` も確認する。

## Phase 2 — Browser 選択・FileChooser・Portal

**対象:** `nix/modules/home/features/desktop-integration/`、`nix/modules/nixos/features/desktop-integration.nix`、`nix/profiles/variants/desktop-integration/{home,nixos}.nix`、`nix/modules/home/features/session-gui.nix`、`nix/modules/home/programs/{glide,firefox,qutebrowser,krita}/`、`nix/modules/home/programs/niri/`、GUI Profile、`media.nix`、`nix/tests/{home,nixos,system}/desktop-integration.nix`、`nix/tests/home/desktop-integration-wrapper.nix`。

- **新 FileChooser API に直接切り替える。** `desktopIntegration.fileChooser.{enable,mode}` を Home / NixOS に導入し、旧 `portal.fileChooser.backend` の設定を新 API へ移行して撤去する。`auto` は backend・追加パッケージ・専用ラッパー・強制設定に寄与しない。`terminal` / `system` は対応 Provider とセッション適用先を明示要求し、提供不能なら理由付きエラー。`enable = false` は自身の寄与だけ停止する。Terminal の有無で chooser を暗黙に選ばない。GUI Profile なし・Media-only・Terminal OFF の Home で desktopIntegration / Glide / fileAssociations が暗黙に要求されず、Media が単独で成立することを確認する。GUI Profile は Media と desktopIntegration を個別に有効化し、Glide を既定選択する。fileAssociations は Phase 3 で Profile に追加する。同じ Phase で Browser Provider と `desktopIntegration.browser.selected`、`media.graphics.krita.enable` を導入し、Linux GUI / TTY の新契約を検証する。
- **Portal Service の所有者を Home と NixOS の双方で分離する。** `auto` で backend も外部 `extraPortals` もない場合、独立 Home **および独立 NixOS** のどちらでも desktopIntegration は `xdg.portal.enable = true` + `extraPortals = []` を生成しない。Portal の起動は NixOS／セッション／明示 Home の管理に委ね、**欠けたパッケージを追加してごまかさず**、最終の Home Manager と NixOS の全 assertion がそれぞれ成立することを受入条件とする。登録済み `desktop-integration-nixos` テストに **Niri OFF・外部 backend なし・FileChooser backend 未指定**を追加し、新 `auto` の無寄与を検証する。独立 Home の Media-only / Terminal OFF ケースも維持する。Host や他 Feature が Portal を有効にしている場合は保持する。TTY は Media／Terminal 単独で Portal・FileChooser・termfilechooser を要求しない。
- **NixOS／Home の FileChooser の保証範囲を区別する。** 暗黙の `termfilechooser` 強制と旧 `mkForce` を撤去する。NixOS 単体の `terminal` は backend の提供とシステム側の実効選択を確認する。統合 Home について (1) NixOS / Home とも `terminal`、(2) NixOS `terminal` / Home `auto` + 動作する外部ラッパー・設定、(3) NixOS `terminal` / Home `auto` + 外部設定なしを評価する。(1)(2) は GUI アプリからのファイル選択完了まで、(3) はシステム側の提供・選択までを合格条件とする。(3) で Home はラッパーを生成せず、暗黙同期しない。
- **Portal の設定出力を Service 有効化から分離する。** NixOS が Portal 本体を管理し Home の `xdg.portal.enable = false` でも、dotfiles が明示的に管理する Home のポリシーは指定先の設定ファイルに出力する。Home が Portal を管理する場合は同一ファイルの二重生成を避ける。Niri の `Secret=none`、`Access`、明示 FileChooser 等の同一管理対象ファイルへの寄与を保持し、`auto` では FileChooser のキーを追加しない。生成物を確認し、管理対象の適切な隔離 D-Bus 環境で明示 chooser の動作を検証する。
- **Portal の探索・解決は upstream に委譲する。** 共通 `portals.conf` と `niri-portals.conf` にそれぞれ明示した設定が各ファイルに出力され、共通の `Secret=none` 等を固有ファイルへ自動転記しないことを確認する。別ファイル・別ディレクトリの実効ポリシーの完全保持、管理外ファイルの探索・自動統合・独自 activation 事前検査は受入条件としない。通常の Nix / Home Manager の同一ファイル衝突処理を利用する。
- **セッション識別と設定管理を分離する。** `sessionGui` の管理対象または Host の明示セッション文脈から `desktopSession.id = niri | sway | null` を導出する。無効な `sessionGui` の既定値や `portal.configName` をセッション識別に用いない。高水準 FileChooser の適用先は既知のセッションまたは Host が明示したセッション固有適用先から決める。未知なら明示 `terminal` / `system` は理由付きエラー、`auto` は成功。Linux 固有の `portal.configName` は独立した出力先とし、別セッションの設定があるだけで競合としない。Niri・Sway・不明の評価と設定出力を検証する。
- Niri の固定 Glide 起動を選択 Provider のコマンドに置き換える。desktopIntegration OFF、選択 `null`、Niri 単独で起動行がないことを確認し、**肯定ケースとして `browser.selected = "qutebrowser"` を追加**する。生成 `config.kdl` の `spawn-at-startup` が選択 Provider の最終実行ファイルを参照し、Qutebrowser の起動行が**正確に1回**、Glide の固定起動行が**0回**であることを確認する。単純な `glide` 行の有効化条件付けだけではテストを通さない。
- Glide の `mkDefault` は GUI Profile / Host の選択としてのみ適用する。Media の有効化だけでは Browser を要求しない。desktopIntegration 単独で Browser 未選択なら `selected = null` とし、Browser を要求しない。Host / Profile で意図した Browser を選択する設定へ移行し、旧 Program フラグの組み合わせから選択順を再現しない。新選択 API、明示 `null` / 別 Provider、選択 Provider の提供と起動コマンドを検証する。
- MIME の所有者切替は Phase 3 にまとめる。Phase 2 では旧 MIME API の全置換動作や複数 Feature の候補順を新たに再現する互換処理・専用テストは追加しない。
- **`desktop-integration-wrapper` を新 API へ直接移行する。** Fixture に `fileChooser.mode = "terminal"` と対象セッションを明示し、Kitty・Alacritty・WezTerm と Yazi の実行経路を検証する。`auto` / `enable = false` では自身の専用ラッパー・FileChooser 選択を追加しないことを確認する。
- Darwin の Glide・ff2mpv 旧経路は維持する。Linux で無効になった `media.programs` の明示設定は移行エラーにする。

## Phase 3 — 独立 fileAssociations Feature と Linux adapters

**対象:** `nix/modules/home/features/media.nix`、`nix/modules/home/features/file-associations/`（新規、内部 Linux adapter 含む）、`desktop-integration/{mime-apps,portal,termfilechooser}.nix`、Feature の import / Profile 構成、Browser 共通設定、関連テスト、`nix/modules/home/programs/yazi/default.nix`。

- **`fileAssociations` を独立した公開 Feature として実装する。** `media.fileAssociations.*` / `desktopIntegration.fileAssociations.*` は導入せず、単一の `fileAssociations.{enable,handlers,linux.mime,autoDefaults}` に関連付けポリシーを集約する。`handlers` を目的ベースの主 API とし、OS 差異吸収・Provider 要求・複数形式の一括設定に価値がある抽象化を提供する。`linux.mime` は任意 MIME 型・Desktop ID・順序付き候補の追加・部分上書き用 Escape Hatch とする（具体的な型・命名は実装開始時に固定）。Linux adapter はそれらを一つの `xdg.mimeApps.defaultApplications` に合成して渡し、固定版 Home Manager のワイルドカード展開・具体 MIME 優先・リスト順序保持をそのまま使う。Media と desktopIntegration は利用者向け既定ポリシーを `xdg.mimeApps` へ直接書かない。旧 API と管理対象 Host の利用者向け直接指定は新 API へ移行し、旧合成結果を再現する機構や独自競合解決器は導入しない。ただし個別 Program の非競合な専用スキーム等と Home Manager の `defaultApplicationPackages` は下記の境界で共存する。
- **依存は一方向の事実参照＋個別 Program 要求とする。** Media は mpv / Krita 等、desktopIntegration は Browser 選択を提供する。fileAssociations は Program の最終状態と実効 Browser 選択を**読み取り**、他 Feature 全体を有効化しない。GUI Profile は fileAssociations の有効化を `lib.mkDefault true` で構成し、Media / desktopIntegration は暗黙に要求しない。Host が OFF にした場合は fileAssociations 自身の寄与だけ停止する。独立した各 Feature と GUI Profile の組み合わせを評価し、Media 単独で他 Feature が有効にならないことを確認する。明示 `handlers.video = "mpv"` 等は個別 Program Provider を `lib.mkDefault true` で要求して最終提供／Desktop Entry を検証し、明示 OFF に負ければ理由付きエラー。**明示ハンドラー → 個別 Program 要求 → Program の最終状態 → 自動既定**の順に評価する。自動既定から Program 要求への逆参照を作らず、要求元による区別は設けない。media / desktopIntegration / fileAssociations の `enable` や `programs.mpv.enable` の相互参照による循環を検出する独立評価テストを追加する。
- **mpv の最終状態による自動既定を表形式の Fixture で固定する。** GUI、fileAssociations / 自動既定 ON、他の明示 MIME・競合候補なしを共通前提とする。`media.mpv.enable = false` + `handlers.video = "mpv"` では mpv Program が最終 ON、`video/*` は明示 mpv、`audio/*` と `image/*` は自動 mpv。Media の要求が OFF でも独立 mpv Program ON なら3カテゴリとも自動 mpv。最終 OFF / Desktop Entry 不在なら3カテゴリの mpv 自動既定はなし（明示要求の失敗は理由付きエラー）。明示 video 要求からの波及を意図した動作として扱い、音声・画像の明示選択や自動既定 OFF は尊重する。カテゴリ単位の停止 API は設けない。`autoDefaults.enable = false` と明示 `handlers.video = "mpv"` の併用で動画だけを寄与し、音声・画像の自動既定を出さないことを検証する。
- **Feature 内部の合成を検証する。** 自動既定 → 明示 `handlers` → `linux.mime` の順で規則を同一入力キー単位に置換・補完してから、一つの設定寄与として Home Manager に渡す。公開 API 経由で `handlers.browser = "glide"` と `linux.mime."text/html" = [ "reader.desktop" "fallback.desktop" ]` を併用し、HTML は reader → fallback のみ、XHTML・HTTP・HTTPS は Glide になることを確認する（外部の独立寄与がない Fixture）。定義順依存の連結を行わない。旧 MIME マップの全置換と旧候補順の完全一致は受入条件とせず、旧明示設定の移行先と変更点を記録する。
- **設定の合成は Nix / Home Manager の既存の意味論に委譲する。** Feature が意図した入力キー・候補リストを渡すことを検証し、同一入力キーの定義合成は Nix、ワイルドカード展開と具体 MIME の適用は Home Manager に任せる。固定版の委譲確認として `video/* = lib.mkForce "chosen.desktop"` と外部 Program の `video/mp4 = lib.mkDefault "external.desktop"` を併用し、生成結果の WebM が `chosen.desktop`、MP4 が `external.desktop` になることを確認する。`text/*` と `text/html` の例も既存の意味論を利用する。`handlers.browser` の変更時は Browser 4種への設定寄与を検証する。展開後の MIME に dotfiles 独自の優先順位を設けない。
- **Home Manager と Program の独立寄与の共存を検証する。** 管理対象 Host の利用者向け直接指定は新 API に移行する。一方、Program の `.desktop` による対応形式登録、Radicle 等の専用スキームの非競合な既定寄与、および `xdg.mimeApps.defaultApplicationPackages` は許容する。`text/html = "chosen.desktop"` と、HTML・PDF を扱うテストパッケージを併用し、生成 `mimeapps.list` が `text/html=chosen.desktop;from-package.desktop`、`application/pdf=from-package.desktop` になることを検査する。複数の package 候補がある場合も固定版 Home Manager の末尾追加順を維持する。外部 Program の既定規則との合成は Nix / Home Manager の既存の意味論に従う。無関係な専用スキームは維持し、fileAssociations OFF / autoDefaults OFF でも外部の独立寄与を消さない。Radicle ON + fileAssociations OFF で `x-scheme-handler/rad` の設定値が残ることを確認し、他の出力要求なしでは `mimeapps.list` が生成されないケースと、Host または外部 Consumer が `xdg.mimeApps.enable = true` を要求して生成されるケースを比較する。fileAssociations OFF は共有基盤を強制 OFF にしない。
- **Emacs 単独 Home の回帰テストを通常の Home 入口から追加する。** Media / desktopIntegration OFF、Emacs Program ON、fileAssociations の独立有効化あり・なしを評価する。`orgProtocol.enable` の既定値が true でも `org-protocol.desktop` が未生成なら `x-scheme-handler/org-protocol` を自動出力しない。Emacs サービスだけ、client だけ、両方 ON を比較し、`text/plain` の自動関連付けはサービスと client の双方が成立し `emacsclient.desktop` が実在する場合だけ生成する。desktopIntegration / orgProtocol 有効時の正のケースも保持し、モジュール import と全 assertion、生成ハンドラーの実在を確認する。
- **Yazi の互換性変更を明記する。** 現行の `desktop-integration-mime` は Yazi 無効でも `inode/directory` と `text/uri-list` を `yazi.desktop` に設定する。新構成では未提供 Yazi の**自動既定**を生成しないことを意図的な変更として扱い、明示 `handlers.directory = "yazi"` は Yazi Program を要求する。旧 Host の directory / URI 規則が変わるケースをテストし、移行案内に記す。 **Provider の有効化契約も修正する。** 現在の `nix/modules/home/programs/yazi/default.nix` は `programs.yazi.enable = true` を通常優先度で設定するため、Host の `false` と Nix の定義衝突になる。Consumer の明示要求を個別 Provider が満たせるよう、Provider 側の有効化要求を適切な既定優先度（例: `lib.mkDefault true`）にする。`handlers.directory = "yazi"` のみで Yazi が実効提供され、Host が `programs.yazi.enable = false` を明示したときは強制上書きも同優先度の定義衝突も起こさず、fileAssociations の理由付き assertion に到達することを検証する。Provider の独自設定の無効化、その他の独立 Consumer の要求についても実効状態を検査する。
- Phase 2 の新 FileChooser API とラッパー・Portal の受入テストは維持する。旧 backend API からの二段階切替や互換動作のテストは設けない。
- Linux の Web Playback adapter を Browser 別に構成する。既定値は選択 Browser・対応 adapter・実効 mpv の成立に従う。Media 単独で Browser 未選択なら既定 OFF、明示 ON なら不足依存を示すエラーとし、他 Feature / Browser を暗黙に有効化しない。Browser あり＋mpv 不在 → 既定 OFF、同条件で明示 ON → エラー、独立 mpv 提供 → 既定 ON を検証する。録画用 `finalPackage` への URL 到達と、OFF／Browser 切替後の Media 由来設定が消えることを確認する。**Firefox の新規プロファイルで ff2mpv が自動的に有効化され、ブラウザー操作から URL を送れること**を受入条件とし、native host 直接呼び出しだけで済ませない。**Qutebrowser を選択した場合は `,m` から現在の URL が `programs.mpv.finalPackage` に届くこと**もテストする。
- 固定版 Home Manager の `xdg.mimeApps.defaultApplications` を生成する adapter のテストでは、入力規則、upstream の `video/*` 展開と具体 MIME の適用、新 API の候補順を確認する。競合するシステム MIME 規則がある場合の実効値は OS / XDG 実装への適用確認として検証し、dotfiles 独自の解決規則は設けない。実効 Program と `mpv.desktop` の存在は別々に検証し、利用者向け既定規則は `fileAssociations` が所有し、生成ファイルは Home Manager が管理して外部の非競合規則と追加候補も保持する。
- TTY Profile は GUI 固有の Feature を要求しない。GUI Profile なしの Media-only Home（Terminal OFF を含む）では他 Feature・Browser・Portal・FileChooser を暗黙に有効化しない。GUI Profile または Host が組み合わせを明示した場合の Web Playback / fileAssociations と、Browser 明示 `null` 時の無寄与を検証する。
- Phase 2 の Portal テストを再利用する。管理対象の指定先への設定生成、`auto` の無寄与、明示 `terminal` / `system` の必要な Provider と適切な環境での動作を確認する。共通・セッション固有ファイル間の自動合成や外部設定との実効優先順位を保証する独自テストは追加しない。
- `media.firefoxIntegration` の Linux 旧設定を移行し、Darwin では既存の経路を維持する。

## Phase 4 — Darwin adapters と旧経路撤去

**対象:** `desktop-integration.nix`、`desktop-integration/org-protocol.nix`、独立 `file-associations/` の Darwin adapter、FileChooser の内部 adapter、`nix/modules/home/programs/emacs/darwin-app.nix`、GUI Profile、`media.nix`、Browser Program、Darwin Home テスト、`nix/ci/default.nix`。

- Darwin GUI Profile にも Media・desktopIntegration・fileAssociations の個別有効化と Browser = Glide の既定選択を適用する。Web Playback は必要な依存が揃う場合に既定 ON とする。Browser 提供は新 Provider、URL 転送は最終 mpv、ファイル選択は利用可能な macOS 標準機構を利用する。
- XDG Portal・XDG MIME・termfilechooser を Darwin の共通機能として起動しない。`orgProtocol.enable` は Darwin の対応実装ができるまで既定 OFF、明示 ON は理由付きエラーとし、XDG Desktop Entry を生成しない。**独立 fileAssociations Feature の Darwin adapter が、今回新設する Launch Services の既定アプリ設定担当**であり、UTI / Bundle ID の解決と `duti` 等による適用を一つの activation 経路にまとめる。現行 `nix/modules/home/programs/emacs/darwin-app.nix` の `registerEmacsApp` は `.app` 登録だけに限定し、`public.plain-text` / `public.source-code` / `public.shell-script` への `duti -s` 書き込みを adapter の有効化と同時に移す。Emacs Program 単独では fileAssociations を要求せず、既定アプリを設定しない（意図的な動作変更）。新規 macOS ユーザーで fileAssociations 未指定 / OFF の場合に旧3種の既定設定を行わないことを確認する。Emacs 有効・別エディターを既定選択・再 activation というケースで、**Launch Services の実効ハンドラーが別エディターの Bundle ID のまま**であり、処理順で Emacs に戻らないことを macOS 上で照会する。対応済み Browser を切り替えた場合も HTML / XHTML の文書型と HTTP / HTTPS の URL スキームの実効ハンドラーを**それぞれ**検証し、OS 同意待ち／拒否／適用成功を区別して完了判定する。Linux の Home Manager MIME と Darwin の UTI API を混同しない。
- **既存ホストとは独立した Darwin Qutebrowser 選択テスト**を追加する。`browser.selected = "qutebrowser"` かつ Web Playback ON とし、生成された `,m` が PATH 上の `mpv` ではなく **`programs.mpv.finalPackage` の実行ファイル**へ URL を渡すことを検査する。Linux の Phase 3 と Darwin の Phase 4 の双方で `,m` 契約を検証する。Program 提供・起動、Web Playback、既定 Browser 関連付けの対応可否は独立に扱う。Darwin Qutebrowser の既定 Browser 関連付けは今回の対象外とし、選択 Browser が Qutebrowser の場合に自動既定から除外されること、`fileAssociations.handlers.browser = "qutebrowser"` の明示要求が理由付きエラーになること、関連付け OFF または別の対応済み Provider の明示選択では Qutebrowser の提供・Web Playback を妨げないことを確認する。固定版 Nixpkgs の `.app` の対応文書型・URL スキーム情報不足の修正は要求しない。将来は upstream 修正を優先し、暫定修正が必要なら Program の package override で扱う。fileAssociations 内でパッケージを修正しない。Darwin Qutebrowser の初回登録・4種の実効照会・OS からの HTTPS URL 受け取りは将来の関連付け対応時の検証とする。
- **Darwin の2ホスト×2テーマ＝4 Home 構成**で `Glide.app`、使用プロファイルの ff2mpv 拡張、manifest の `allowed_extensions` と拡張 ID の一致、Glide 連携から `programs.mpv.finalPackage` への URL 到達を新契約として検証し、Darwin の切替と同時に `media.programs`・`media.firefoxIntegration` の旧経路を撤去する。通常 PR CI の代表 Home 1件だけでは承認しない。
- 旧 MIME / FileChooser / Emacs 既定アプリの移行先と意図的な動作変更を記録する。旧副作用・候補合成の完全再現は要求しない。

### Phase 4 必須の Darwin Home ビルド

通常 PR CI の代表ビルドとは別に、次の4件を **macOS runner 上で全件**実行する（移行 PR の必須チェックに追加）。

```sh
nix build --no-update-lock-file \
  '.#checks.aarch64-darwin.build-home-aarch64-darwin-a--account-a--theme-light' \
  '.#checks.aarch64-darwin.build-home-aarch64-darwin-a--account-a--theme-dark' \
  '.#checks.aarch64-darwin.build-home-aarch64-darwin-hiromichisugiura--account-hiromichisugiura--theme-light' \
  '.#checks.aarch64-darwin.build-home-aarch64-darwin-hiromichisugiura--account-hiromichisugiura--theme-dark'
```

ビルドに加え、各 Home の生成物について Glide の拡張・native host 対応・最終 mpv への URL 引き渡しを検査する。Darwin 実機での GUI 操作確認は別途行う。

## 完了条件

`nix/tests/home/desktop-integration.nix`、`nix/tests/home/desktop-integration-mime.nix`（移行後の独立 Feature テストを追加）、`nix/tests/home/desktop-integration-wrapper.nix`、`nix/tests/nixos/desktop-integration.nix`（`desktop-integration-nixos`）、`nix/tests/system/desktop-integration.nix`、Niri／Darwin／Media テストを更新して `nix/checks.nix` に登録する。

各 Phase で対象の Linux GUI・TTY・Darwin GUI 構成が成立し、新 API の契約を満たすことを検証する。Linux の Portal テストは Session Provider の Niri・Sway・未指定を分け、**`auto` の無寄与（選択はセッションに委譲）と明示選択時の設定寄与・必要 Provider・適切な管理対象環境での動作**を区別して検証する。**テストは機能別に整理し、OS 別ケースは内部実装の差異を検証するために用いる。** `flake check` と整形環境由来の失敗は区別して記録する。
