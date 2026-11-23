# Media / desktopIntegration リファクタリング実装計画

**前提:** [設計仕様](../specs/2026-11-21-media-desktop-integration-design.md)

## Phase 1 — mpv の独立化

**対象:** `nix/modules/home/programs/mpv/default.nix`（新規）、`nix/modules/home/features/media.nix`。

- `media.mpv.settings` を Program に移し、`autofit-large` を `autofit-larger` に修正する。旧オプションは移行先を示すエラーにする。
- `programs.mpv.finalPackage` を実効実行ファイルとして扱い、`scripts` や package 上書きも反映する。
- 生成 `mpv.conf` の読み込み結果について、終了コードだけでなく `Error parsing option` を検査する。単独利用と `package = null` も確認する。

## Phase 2 — Browser 選択・提供

**対象:** `nix/modules/home/features/desktop-integration/`、`nix/modules/nixos/features/desktop-integration.nix`、`nix/profiles/variants/desktop-integration/{home,nixos}.nix`、`nix/modules/home/features/session-gui.nix`、`nix/modules/home/programs/{glide,firefox,qutebrowser,krita}/`、`nix/modules/home/programs/niri/`、GUI Profile、`media.nix`、`nix/tests/{home,nixos,system}/desktop-integration.nix`、`nix/tests/home/desktop-integration-wrapper.nix`。

- **旧経路の撤去前に**、FileChooser の未指定時既定を **セッション／OS 既定への委譲**に変更する。旧 `portal.fileChooser.backend` が未指定なら FileChooser の backend・追加パッケージ・ラッパー・強制設定を寄与しない。従来の未指定既定 `termfilechooser` からの意図的変更として明示する。**Terminal が有効なだけでは termfilechooser を選ばない。** Host が指定済みの `"gtk"` / `"termfilechooser"` / `null` は従来どおり優先し、Terminal ON + 明示 GTK は GTK、明示 `null` は無寄与と検証する。明示 backend の適用先が実効セッション／明示 `portal.configName` から特定できない場合は理由付きエラーを出し、共通ファイルだけで保証したことにしない。**GUI Profile なし・Media-only・Terminal OFF** の Home で desktopIntegration が自動 ON、Glide が実効提供され、Terminal 不在に起因する評価失敗や FileChooser 強制設定がないことを確認する（GTK の選択は要求しない）。**このテストを満たす同じ変更で** Browser Provider と `desktopIntegration.browser.selected` を導入し、Linux GUI 既定を `lib.mkDefault "glide"` に移す。Media 旧 Browser 提供の撤去を先行しない。同じ変更で Krita を `media.graphics.krita.enable` に移し、Linux GUI で提供、TTY では要求なしを確認する。
- **Portal Service の所有者を Home と NixOS の双方で分離する。** `auto` で backend も外部 `extraPortals` もない場合、独立 Home **および独立 NixOS** のどちらでも desktopIntegration は `xdg.portal.enable = true` + `extraPortals = []` を生成しない。Portal の起動は NixOS／セッション／明示 Home の管理に委ね、**欠けたパッケージを追加してごまかさず**、最終の Home Manager と NixOS の全 assertion がそれぞれ成立することを受入条件とする。登録済み `desktop-integration-nixos` テストに **Niri OFF・外部 backend なし・FileChooser backend 未指定**を追加し、既存の「既定 termfilechooser」期待値を新 `auto` に更新する。独立 Home の Media-only / Terminal OFF ケースも維持する。Host や他 Feature が Portal を有効にしている場合は保持する。TTY は Media／Terminal 単独で Portal・FileChooser・termfilechooser を要求しない。
- **NixOS／Home の切替を同じ Phase で整合させる。** 管理対象 Linux GUI が委譲型 `auto` へ移るなら、NixOS 側の暗黙の `portal.fileChooser.backend = "termfilechooser"` と `mkForce` を同時に撤去する。端末 chooser を維持するホストでは Home のラッパーと NixOS の backend を**明示的な要求として**維持する。**NixOS 単体で明示 terminal（Phase 2 は旧 `portal.fileChooser.backend = "termfilechooser"`）を指定した場合の合格条件は、backend の導入とシステム側 Portal の実効選択まで**とし、端末・Yazi ラッパーやファイル選択完了は要求しない。**NixOS + 内包 Home** では、実効 FileChooser の選択、backend パッケージ、端末・Yazi ラッパーの有無を整合させ、GUI アプリからの実際のファイル選択完了までを確認する。独立 NixOS と統合 Home の評価を別の受入ケースに分ける。
- **Portal Policy Composition を Service 有効化から分離する。** NixOS が Portal 本体を管理して Home の `xdg.portal.enable` が false でも、Home の明示 `portal.secretBackend = "none"` 等から **実際の `xdg.configFile."xdg-desktop-portal/niri-portals.conf"`** を生成・配置する経路を Phase 2 で導入する。Home Manager の `xdg.portal.config` が残るだけでは不合格。Home が `xdg.portal.enable = true` の構成では従来の生成経路と重複させず、同一パスの単一所有と Host の明示ポリシーの合成を保証する。隔離 D-Bus の **NixOS（`Secret=gnome-keyring`）+ 内包 Home（`Secret=none`、chooser `auto`）** 統合テストで、ユーザー側 `niri-portals.conf` の生成物と実効 `Secret=none` の両方を確認する。FileChooser が `auto` でも非 FileChooser ポリシーを無視せず、既存の `Inhibit=none` 等に回帰がないことを確認する。
- **セッション識別と設定管理を分離する。** 有効な `sessionGui` は Niri 等の設定を管理し、別の内部実効値 `desktopSession.id = niri | sway | null` がセッション識別を提供する。Sway の識別だけで設定・起動管理を強制しない。`sessionGui.enable = false` なら `sessionGui.session` の既定 `niri` を利用せず、Host 明示セッション／既存 `portal.configName = "sway"` を必要なときに解決する。有効な `sessionGui.session = "niri"` と明示 `portal.configName = "sway"` は競合エラー＋移行案内とする。Niri・Sway・不明・独立 Home の各評価テストを追加する。Session Provider は適用先を、FileChooser Provider は実装を、Portal Composition は Host 明示ポリシーとの合成を担当する。
- Niri の固定 Glide 起動を選択 Provider のコマンドに置き換える。desktopIntegration OFF、選択 `null`、Niri 単独で起動行がないことを確認し、**肯定ケースとして `browser.selected = "qutebrowser"` を追加**する。生成 `config.kdl` の `spawn-at-startup` が選択 Provider の最終実行ファイルを参照し、Qutebrowser の起動行が**正確に1回**、Glide の固定起動行が**0回**であることを確認する。単純な `glide` 行の有効化条件付けだけではテストを通さない。
- Glide の `mkDefault` は GUI Profile または Media の GUI 要求があるときだけ適用する。**GUI Profile なし・Media OFF の desktopIntegration 単独**で、Browser がない場合は `selected = null` かつ Browser 関連付けなしを検証する。現行の **Qutebrowser のみ有効な Home** は `browser.selected = "qutebrowser"`、**Glide のみ**または **Glide + Qutebrowser** が有効な Home は `browser.selected = "glide"` へ移行する。いずれも HTML・XHTML・HTTP・HTTPS の4件が従来の Browser を指すことを検証する。旧 Program フラグを Browser 選択 API と同一視せず、必要な Host の明示設定を更新する。
- Linux では新 Provider から Browser 4関連付けを生成する。ただし Phase 2 中は **旧 `mimeApps.defaultApplications` の全置換 semantics を変更しない**。**desktopIntegration 単独**で `inode/directory` だけを指定した場合は、同 Feature の関連付け寄与が1件であることを検証する。**Media 併用**ではそのディレクトリ設定と Media の `video/mp4` 等の関連付けがともに最終 `mimeapps.list` に残ることを確認する（展開後の総件数は固定しない）。新 API の部分上書きは別途検証する。
- 既存の **`desktop-integration-wrapper` チェックも Phase 2 で移行**する。`nix/tests/home/desktop-integration-wrapper.nix` の Fixture に旧 `portal.fileChooser.backend = "termfilechooser"` と対象セッションを明示し、生成されたラッパーから Kitty・Alacritty・WezTerm、Yazi への引数・起動経路を引き続き確認する。未指定 `auto` の Fixture はラッパーなしを別途確認する。
- Darwin の Glide・ff2mpv 旧経路は維持する。Linux で無効になった `media.programs` の明示設定は移行エラーにする。

## Phase 3 — 機能 API と Linux adapters

**対象:** `nix/modules/home/features/media.nix`、`desktop-integration/{mime-apps,portal,termfilechooser}.nix`、Browser 共通設定、関連テスト。

- `media.mimeApps` と `desktopIntegration.mimeApps` を **論理 Provider 選択の便利 API と Home Manager 既存 MIME API の併用**へ移す。明示的な `media.fileAssociations.video = "mpv"` 等の論理選択は対応 Program を `lib.mkDefault true` で要求し、最終 Program / Desktop Entry を検証する。明示 OFF と衝突する場合は理由付き契約エラー。自動既定は実効 Program がある場合のみ低優先度で出力し、mpv が最終 OFF／`mpv.desktop` 不在なら `video/*`・`audio/*`・`image/*` の mpv 自動指定を出力しない。mpv 不在 + 明示した別ハンドラーを維持し、同じ Fixture で Web Playback 既定 OFF と MIME 実効値を検証する。**候補順、ワイルドカード、個別 MIME、任意 Desktop ID は `xdg.mimeApps.defaultApplications` に直接指定**し、新 API に複製しない。Feature 自動既定は低優先度とし、Home Manager の Host 明示値が優先する。旧 `desktopIntegration.mimeApps.defaultApplications` の全置換動作は Phase 2 まで維持し、Phase 3 は `desktopIntegration.fileAssociations.autoDefaults.enable = false` + Home Manager 直接指定に明示的に移す。旧設定を部分合成へ黙って変換せず、個別設定を含む移行例と不一致時の移行エラーを用意する。
- `desktopIntegration.fileChooser.{enable,mode}` を追加。**`auto` は backend を選ばず、Portal の FileChooser 指定・パッケージ・ラッパーを追加せず、Session Provider／OS 既定へ委譲**する。Terminal 有無で GTK／termfilechooser を自動強制する案は撤回する。`mode = "terminal"` は Linux の termfilechooser、`mode = "system"` は Linux の GTK（Darwin では OS 標準）を**明示要求**し、Session Provider／明示適用先と Portal Composition で実効動作を保証する。対応できない場合は理由付きエラー。`enable = false` は FileChooser だけ無寄与とし、外部から `FileChooser=gtk` と対応 `xdg-desktop-portal-gtk` を提供した際の実効選択をテストする。旧 `backend = "gtk"` / `"termfilechooser"` / `null` と新 `system` / `terminal` / `enable = false` の移行を明示し、`portal.*` の高度な設定は実装固有として扱う。**Phase 2 のラッパーテストを Phase 3 で `fileChooser.mode = "terminal"` へ切替**し、明示選択テストとして維持する。
- Linux の Web Playback adapter を Browser 別に構成する。既定値は選択 Browser・対応 adapter・実効 mpv の成立に従う。Browser あり＋mpv 不在 → 既定 OFF、同条件で明示 ON → エラー、独立 mpv 提供 → 既定 ON を検証する。録画用 `finalPackage` への URL 到達と、OFF／Browser 切替後の Media 由来設定が消えることを確認する。**Firefox の新規プロファイルで ff2mpv が自動的に有効化され、ブラウザー操作から URL を送れること**を受入条件とし、native host 直接呼び出しだけで済ませない。**Qutebrowser を選択した場合は `,m` から現在の URL が `programs.mpv.finalPackage` に届くこと**もテストする。
- 固定版 Home Manager の `xdg.mimeApps.defaultApplications` におけるリスト順序保持・`video/*` 展開・正確な `video/mp4` 指定の優先を利用し、mpv 固定の `video/mp4` 規則は重複追加しない。論理ハンドラー変更で `video/mp4` が追従するのは **Host の `video/mp4` 明示規則がないときだけ**。移行例は `"video/*" = [ "first.desktop" "second.desktop" ]; "video/mp4" = "special.desktop";` とし、生成された `mimeapps.list` の候補順と個別規則を旧 API と比較する。競合するシステム規則を持つ隔離 XDG 環境で実効結果を照会し、Program の実効提供と `mpv.desktop` の存在も別途検証する。
- TTY では GUI 固有の関連付け・Portal・FileChooser を既定 OFF にし、従来のホストテストを更新する。**Terminal OFF の `auto` は成功するが GTK の選択までは保証しない**。`auto` は Terminal ON/OFF いずれも chooser の強制設定・専用ラッパーを寄与しない。明示 `terminal` で Terminal 不在ならエラー。Phase 2 の **GUI Profile なし・Terminal OFF の Media-only GUI Home** の Glide／desktopIntegration／無強制テストを維持し、Web Playback の実効提供と Browser 明示 `null` 時の無寄与も確認する。
- Portal の受入テストは **`auto` の FileChooser 無寄与**と **明示選択の実効保証**を分離する。`auto` 中でも Host が明示した `Secret` / `Access` 等のポリシーはユーザー設定へ出力し、ファイル生成と実効値まで検証する。`auto` では Niri・Sway・セッション不明の既存 Portal 設定を変更せず、セッション／OS 既定に委譲する。明示 `terminal` / `system` では、対象 Niri / Sway 固有設定にそれぞれ `termfilechooser` / `gtk` を反映する。ユーザー側 `sway-portals.conf` が既存 GTK を指定していても明示 terminal の実効値が termfilechooser になること、明示 system も逆方向に勝つことを隔離 D-Bus セッションで確認する。対象セッション不明で共通 `portals.conf` のみでは保証できない場合、**terminal・system 両方**を理由付きエラーとする。新設したユーザー側 `sway-portals.conf` のため共通 `Access=none` / `secretBackend` が消えないよう明示ポリシーを合成する。さらに**システム側とユーザー側の設定を別ディレクトリ**に配置した隔離 D-Bus テストで、システム側 `sway-portals.conf` の `Inhibit=none` が、ユーザー側で chooser を `gtk` / `termfilechooser` に切り替えた後も**実効 `none` のまま**であることを確認する。単に FileChooser / Access だけが通るテストや、ユーザー側に `default=gnome;gtk` を無条件に書く実装では合格としない。共通設定は他セッション向けに維持する。管理対象外の競合は検出する。`portal.configName = "common"` + 高度なポリシーも検証し、有効な `sessionGui.session = "niri"` と明示 `portal.configName = "sway"` の衝突は理由付き移行エラーとする。
- `media.firefoxIntegration` の Linux 旧設定を移行し、Darwin では既存の経路を維持する。

## Phase 4 — Darwin adapters と旧経路撤去

**対象:** `desktop-integration.nix`、`desktop-integration/org-protocol.nix`、関連付け／FileChooser の内部 adapter、`nix/modules/home/programs/emacs/darwin-app.nix`、GUI Profile、`media.nix`、Browser Program、Darwin Home テスト、`nix/ci/default.nix`。

- Darwin GUI にも Browser = Glide、Web Playback = ON の機能的な既定動作を適用する。Browser 提供は新 Provider、URL 転送は最終 mpv、ファイル選択は利用可能な macOS 標準機構を利用する。
- XDG Portal・XDG MIME・termfilechooser を Darwin の共通機能として起動しない。`orgProtocol.enable` は Darwin の対応実装ができるまで既定 OFF、明示 ON は理由付きエラーとし、XDG Desktop Entry を生成しない。**Darwin fileAssociations adapter は今回新設する Launch Services の既定アプリ設定担当**であり、UTI / Bundle ID の解決と `duti` 等による適用を一つの activation 経路にまとめる。現行 `nix/modules/home/programs/emacs/darwin-app.nix` の `registerEmacsApp` は `.app` 登録だけに限定し、`public.plain-text` / `public.source-code` / `public.shell-script` への `duti -s` 書き込みを adapter の有効化と同時に移す（旧 Emacs 既定の互換性も明示的に移行）。Emacs 有効・別エディターを既定選択・再 activation というケースで、**Launch Services の実効ハンドラーが別エディターの Bundle ID のまま**であり、処理順で Emacs に戻らないことを macOS 上で照会する。Linux の Home Manager MIME と Darwin の UTI API を混同しない。
- **既存ホストとは独立した Darwin Qutebrowser 選択テスト**を追加する。`browser.selected = "qutebrowser"` かつ Web Playback ON とし、生成された `,m` が PATH 上の `mpv` ではなく **`programs.mpv.finalPackage` の実行ファイル**へ URL を渡すことを検査する。選択した Browser の Darwin Provider が未対応なら契約エラーとし、対応実装なしに成功とみなさない。Linux の Phase 3 と Darwin の Phase 4 の双方で `,m` 契約を検証する。
- **Darwin の2ホスト×2テーマ＝4 Home 構成**で `Glide.app`、使用プロファイルの ff2mpv 拡張、manifest の `allowed_extensions` と拡張 ID の一致、Glide 連携から `programs.mpv.finalPackage` への URL 到達を検証してから、`media.programs`・`media.firefoxIntegration` の旧経路を同時撤去する。通常 PR CI の代表 Home 1件だけでは承認しない。
- 旧 `mimeApps`／FileChooser backend の明示設定は、論理 Provider の便利 API と Home Manager の詳細 MIME 指定への移行先、または理由付き移行エラーで扱う。従来の候補順・個別 MIME 上書き・Emacs の Darwin 既定アプリの副作用を黙って変更しない。

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

`nix/tests/home/desktop-integration.nix`、`nix/tests/home/desktop-integration-mime.nix`、`nix/tests/home/desktop-integration-wrapper.nix`、`nix/tests/nixos/desktop-integration.nix`（`desktop-integration-nixos`）、`nix/tests/system/desktop-integration.nix`、Niri／Darwin／Media テストを更新して `nix/checks.nix` に登録する。

各 Phase で Linux GUI・TTY・Darwin GUI の既存構成と実効出力を検証する。Linux の Portal テストは Session Provider の Niri・Sway・未指定を分け、**`auto` の無寄与（選択はセッションに委譲）と明示選択時の xdg-desktop-portal 実効 backend**を区別して検証する。**テストは機能別に整理し、OS 別ケースは内部実装の差異を検証するために用いる。** `flake check` と整形環境由来の失敗は区別して記録する。
