# Media / desktopIntegration / fileAssociations リファクタリング実装計画

**前提:** [設計仕様](../specs/2026-11-21-media-desktop-integration-design.md) を提供契約の正とする。以下は差分タスクと受入条件。

## 着手前の基準チェック

`desktop-integration-home` Fixture の Kitty が参照する Catppuccin オプション未宣言を修正する。通常の Home 入口または必要モジュール・引数を使用し、Kitty の設定を削除しない。`nix flake check --no-update-lock-file path:.` を再実行し、treefmt と評価・ビルド・実行失敗を区別する。

## Phase 1 — mpv の独立化

**対象:** `nix/modules/home/programs/mpv/default.nix`（新規）、`nix/modules/home/features/media.nix`。

- `media.mpv.settings` を Program へ移行（旧オプションは移行エラー）。autofit-large → autofit-larger を修正。
- scripts・package 上書き込みの `programs.mpv.finalPackage`、独立利用、package null を検証する。mpv.conf の読み込みは終了コードに加え Error parsing option がないことを確認する。

## Phase 2 — Session Provider・Browser 選択・FileChooser・Portal

**対象:** `nix/modules/home/features/desktop-integration/`、`nix/modules/nixos/features/desktop-integration.nix`、`nix/profiles/variants/desktop-integration/{home,nixos}.nix`、`nix/modules/{home,nixos}/features/session-gui.nix`、内部 Session Provider、`nix/modules/home/programs/{glide,firefox,qutebrowser,krita}/`、`nix/modules/home/programs/niri/`、GUI Profile、`media.nix`、`nix/tests/{home,nixos,system}/desktop-integration.nix`、`nix/tests/home/desktop-integration-wrapper.nix`。

### 実装・移行

- Home / NixOS の Niri Session Provider を分離し、Greeter / Portal を実効 Provider 参照へ切り替える。NixOS programs.niri.enable の要求は mkDefault。
- Browser Provider・`browser.selected`・`media.graphics.krita.enable` を導入し、Niri の固定 Glide 起動を選択コマンドに変更。Qutebrowser の有効化要求も mkDefault。
- Linux GUI Profile で Media・desktopIntegration を個別に有効化し、Glide と `fileChooser.mode = lib.mkDefault "terminal"` を明示する。Feature の mode 既定は auto。fileAssociations は Phase 3 で Profile に追加。
- NixOS の旧 FileChooser 提供・選択・専用 Profile 寄与と旧無条件 mkForce を撤去する。上流 Niri の既定 GTK ポリシーと NixOS xdg.portal.* は保持。Home に backend 登録とポリシー出力を実装する。
- 旧 `desktopIntegration.portal.enable` を両側から撤去し、旧 OFF の意図を個々の寄与へ移す。旧 `portal.fileChooser.backend` は termfilechooser → terminal、gtk / null → auto。GTK 明示指定が必要な場合は低水準 Portal ポリシーへ移す。旧 API の互換動作は再現しない。Home の旧 FileChooser 実体・設定を新契約へ切り替える。
- 組み込み Home は u 等のシステム切替一回で両側更新。独立 Home はシステムの旧 backend・登録撤去 → Home 更新。両者とも OS 再起動で反映し、混在世代は保証しない。u の変更や個別サービスの手動反映手順は不要。
- MIME 所有者の切替は Phase 3。Darwin の Glide / ff2mpv 旧経路を保持し、Linux で無効になった media.programs の明示設定は移行エラーにする。

### 受入条件

**評価・生成物**

| ケース | 期待結果 |
| --- | --- |
| Niri ON / OFF、独立 Niri ON + sessionGui OFF | 選択時だけ実効 Provider。Greeter・Portal は選択情報を参照（テスト Provider でも確認） |
| Niri / Qutebrowser を要求、Host の通常 false（Niri の mkForce false も） | 定義衝突でなく理由付き assertion |
| Profile、Feature 単独、Host auto 上書き | Linux GUI の terminal、単独の auto、上書きの auto を確認 |
| terminal + sessionGui OFF / Terminal Provider 不在 / NixOS Portal OFF | 各依存不足を示す assertion |
| 独立 NixOS の Niri OFF・backend なし、独立 Home の auto / Media-only / Terminal OFF | 全 assertion 成立、空 extraPortals の本体要求なし |
| auto + GTK 未提供（GNOME のみ） | GTK を暗黙要求しない |
| desktopIntegration OFF / Browser null / Niri 単独 | 自動起動行なし。Browser 未選択なら要求なし |
| Browser = qutebrowser | 最終コマンドの spawn-at-startup が1回、固定 Glide は0回 |

独立 Home terminal のホスト基盤前提を明記する。既存 desktop-integration-wrapper を移行し、Kitty / Alacritty / WezTerm と Yazi の実行経路を確認する。Yazi package null + 代替なしは型エラーではなく理由付き assertion、互換 fileManager.package 指定時はラッパー生成・実行が成立する。auto では chooser ラッパー・選択キー・専用 backend の寄与なし。

**Portal ポリシー:** Home の xdg.portal.enable=false でも実ファイルを生成し、auto + Secret=none は Secret のみ（暗黙 default / FileChooser なし）、terminal + Secret=none / Access の各明示寄与を保持する。共通 portals.conf と niri-portals.conf の独立出力・自動転記なしを確認。Home の明示 FileChooser 規則と Secret の実効適用を独立に検証し、各設定を除去する負の Fixture または選択ログで UseIn フォールバックによる偽陽性を排除する。

**実セッションの完了ゲート:** 実 NixOS / Niri の OS 再起動を挟んで auto → terminal（D-Bus サービスディレクトリ未作成の初回を含む）→ auto を試験する。

- terminal: Home 提供 .portal / D-Bus / systemd user unit の解決と D-Bus / systemd 経由の起動を確認。FragmentPath / ExecStart / 実プロセスが Home の選択パッケージを指すことを検証する。
- GTK アプリの OpenFile で Kitty 上の Yazi が選択した空白入りファイルの URI が返ることを別途確認。先に Portal が起動していてもよい。隔離 D-Bus の負例（サービス定義なし）も保持し、選択ログだけでは合格としない。
- auto: Home の旧 chooser 寄与が消え、適切な管理対象 Niri 環境で標準 chooser が動作する。移行後の Home backend ExecStart 確認は terminal 選択時のみ。

隔離環境の成功は実セッションの代替にしない。Phase 2 完了には上記が必要（実 NixOS / Niri は未検証）。

## Phase 3 — 独立 fileAssociations Feature と Linux adapters

**対象:** `nix/modules/home/features/media.nix`、`nix/modules/home/features/file-associations/`（新規、内部 Linux adapter 含む）、`desktop-integration/{mime-apps,portal,termfilechooser}.nix`、Feature の import / Profile 構成、Browser 共通設定、関連テスト、`nix/modules/home/programs/{yazi,mpv}/default.nix`、`nix/modules/home/features/terminal.nix` と Terminal Provider。

### 実装・移行

- fileAssociations と Linux adapter を追加し、GUI Profile から独立に mkDefault 有効化。旧 media.mimeApps / desktopIntegration.mimeApps と管理対象 Host の利用者向け直接指定を一括移行。詳細 API 型を確定し、設計の合成順と提供条件を適用する。
- mpv Program に画像 MIME 追加登録を実装し、固定版 Desktop Entry・表示確認に基づく有限の対応型集合を明示・自動双方に使用。
- Terminal Provider の Desktop ID を xdg.terminal-exec に渡し、Yazi Provider の enable 要求を mkDefault にする。Emacs の Server 提供条件を Org Protocol と textEditor で共有する。
- Browser 別 Web Playback adapter を実装し、Linux の旧 media.firefoxIntegration を移行。Darwin 旧経路は Phase 4 まで維持。

### 受入条件

**独立構成:** Media-only（TTY / Terminal OFF 含む）、desktopIntegration-only、fileAssociations-only、GUI Profile、個別 Program ON/OFF の評価で依存循環・暗黙の他 Feature 要求がないこと。desktopIntegration OFF で selected=glide が残っても Browser 由来の自動4種・Web Playback が停止し、独立 Glide と明示 Browser handler は成立。Browser null も確認。

**mpv:** Linux GUI・自動既定 ON・競合なしの Fixture を共通前提とする。

| 構成 | 既定結果 |
| --- | --- |
| media.mpv OFF + 明示 video=mpv | video 明示、audio / image 自動 |
| 独立 mpv ON | 3カテゴリ自動 |
| 最終 OFF / package null | 自動なし、明示要求はエラー |
| autoDefaults OFF + 明示 video | 動画のみ |

IFD 禁止で標準・契約を満たす明示カスタム・overlay の同等性を評価。標準最終パッケージの bin/mpv と mpv.desktop をビルド検査する。録画用 Web Playback Fixture も提供契約を満たす。Program の Added Associations は fileAssociations / autoDefaults OFF でも維持。Added Associations / Default Applications、GIO 既定・登録照会と実際の PNG / JPEG 表示、対応動画・音声の代表例を検証する。

**合成・共存:** 外部寄与なしの Fixture と共存 Fixture を区別する。

| 入力 | 期待結果 |
| --- | --- |
| handlers.browser=glide + linux.mime."text/html" = ["reader.desktop" "fallback.desktop"] | HTML は reader → fallback、XHTML・HTTP・HTTPS は Glide |
| video/* = mkForce "chosen.desktop" + 外部 video/mp4 = mkDefault "external.desktop" | WebM は chosen、MP4 は external（text/* と text/html も確認） |
| HTML chosen + HTML/PDF を提供する defaultApplicationPackages | HTML は chosen → from-package、PDF は from-package。複数 package の末尾順も確認 |
| Radicle ON + fileAssociations OFF | rad の設定値保持。他の出力要求なしは生成なし、xdg.mimeApps.enable=true なら生成 |

競合するシステム規則の実効値は OS / XDG の適用確認として検証。外部独立寄与を削除しない。

**Emacs:** 通常 Home 入口で Media / desktopIntegration OFF・Emacs ON と fileAssociations ON/OFF を評価。未生成 org-protocol.desktop への自動規則なし。サービスのみ / client のみ / 両方 ON と Server 起動経路の有無を比較し、text/plain の条件を検証。明示 textEditor は autoDefaults OFF でも適用、依存の明示 OFF で理由付きエラー。サービス・client ON かつ socketActivation / startWithUserSession 両方 OFF も負例。Org Protocol の既定 OFF / 明示エラーを確認。Server 未起動・socket 待受中に生成 Desktop Entry から URL が Org handler に届くこと、初回の実ファイルが Emacs バッファに届くことを別々に検証。セッション起動経路も確認する。

**Yazi:** GUI 端末経路ありの明示 directory= yazi から Program が提供され、Host の通常 false で理由付き assertion に到達すること。Yazi 未提供なら inode/directory / text/uri-list 自動規則なし（旧動作からの変更）。Yazi と terminal-exec の enable=true / package=null を個別・両方で検証し、外部提供なしなら自動既定なし・明示エラー（型エラーで隠さない）。Kitty / Alacritty / WezTerm の Desktop Entry・子コマンド起動、GIO の既定・登録・実際のディレクトリ引き渡しを検証する。

**Web Playback:** Browser なし / adapter なし / mpv なしで既定 OFF・明示 ON エラー、独立 mpv で成立。契約を満たす録画用 finalPackage への URL 到達、OFF / Browser 切替後の設定撤去を検証する。Firefox 新規プロファイルで ff2mpv が有効となり Browser 操作で送信できること（native host 直接呼出しのみでは不可）。Qutebrowser は `,m` で現在 URL を最終 mpv へ渡す。Phase 2 Portal / wrapper の回帰テストを維持。

## Phase 4 — Darwin adapters と旧経路撤去

**対象:** `desktop-integration.nix`、`desktop-integration/org-protocol.nix`、独立 `file-associations/` の Darwin adapter、FileChooser の内部 adapter、`nix/modules/home/programs/emacs/darwin-app.nix`、GUI Profile、`media.nix`、Browser Program、Darwin Home テスト、`nix/ci/default.nix`。

- Darwin GUI Profile に Media・desktopIntegration・fileAssociations と Glide を適用。FileChooser auto は無寄与、terminal は理由付きエラー。Org Protocol は既定 OFF、明示 ON はエラー。XDG Portal / MIME / Desktop Entry を生成しない。
- Darwin fileAssociations adapter と activation DAG を導入し、registerEmacsApp の duti -s を移す。copyApps → registerEmacsApp → 既定設定と他 Provider の登録完了を生成 activation で確認。新規ユーザーで初回要求・必要な OS 同意の承認後の実効値確認を分け、未承認・拒否を成功扱いしない。

### 実機・生成物の受入条件

| 対象 | 確認 |
| --- | --- |
| Emacs 単独、fileAssociations 未指定 / OFF | 新規ユーザーで旧3種 UTI を設定しない |
| 明示 textEditor=emacs | 初回 activation で要求、承認後に3種 UTI を個別照会 |
| Emacs ON + 別 editor | Fixture の公開 handlers.textEditor="test-editor" から登録済みテストアプリを選択、再 activation 後も3種が別 Bundle ID のまま。テスト Provider は本番に混ぜない |
| Browser 切替 | HTML / XHTML / HTTP / HTTPS をそれぞれ承認後に実効照会 |
| mpv | 標準 .app の Bundle ID と動画・音声登録をビルド検証。対応 UTI の自動既定・autoDefaults OFF の明示 video/audio、画像の無寄与・明示未対応エラー |
| Qutebrowser | 独立 Fixture の選択と Web Playback ON、,m から finalPackage の実行ファイルへ URL 到達。Browser 自動既定なし・明示エラー、関連付け OFF / 他 Provider 選択でも Program と Web Playback は維持 |
| Glide | 4 Home 全件で Glide.app、使用プロファイルの ff2mpv、manifest allowed_extensions と拡張 ID の一致、URL が最終 mpv へ到達 |

テスト用 editor は実ファイルを受け取れる登録済みアプリを用いる。Qutebrowser の文書型・URL スキーム登録と OS 経由の URL 受け取りは将来の関連付け対応時に検証する。Darwin 切替と同時に media.programs / media.firefoxIntegration の旧経路を撤去する。

### 必須 Darwin Home ビルド

nix/ci/default.nix の通常 PR・全体ビルドの macos-14 を macos-latest へ変更し、ワークフローを再生成する。実ジョブが aarch64-darwin であることを確認する（着手前に独立実施可）。移行 PR は代表1件でなく以下の4件を macOS runner で必須とする。

```sh
nix build --no-update-lock-file \
  '.#checks.aarch64-darwin.build-home-aarch64-darwin-a--account-a--theme-light' \
  '.#checks.aarch64-darwin.build-home-aarch64-darwin-a--account-a--theme-dark' \
  '.#checks.aarch64-darwin.build-home-aarch64-darwin-hiromichisugiura--account-hiromichisugiura--theme-light' \
  '.#checks.aarch64-darwin.build-home-aarch64-darwin-hiromichisugiura--account-hiromichisugiura--theme-dark'
```

4件の生成物検証と macOS 実機操作は別の受入条件。runner image 更新は許容し Nix inputs の固定と区別する。

## 完了条件

`nix/tests/home/desktop-integration.nix`、`nix/tests/home/desktop-integration-mime.nix`（移行後の独立 Feature テストを追加）、`nix/tests/home/desktop-integration-wrapper.nix`、`nix/tests/nixos/desktop-integration.nix`（`desktop-integration-nixos`）、`nix/tests/system/desktop-integration.nix`、Niri／Darwin／Media テストを更新して `nix/checks.nix` に登録する。

各 Phase の Linux GUI / TTY / Darwin GUI の管理対象構成を成立させ、機能別の回帰テスト（OS 差は内部実装のケース）を通す。旧設定の移行先と意図的な動作変更を記録する。実機未検証の項目を完了扱いにしない。
