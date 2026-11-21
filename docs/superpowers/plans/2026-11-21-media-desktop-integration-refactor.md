# Media / desktopIntegration リファクタリング実装計画

**前提:** [設計仕様](../specs/2026-11-21-media-desktop-integration-design.md)

## Phase 1 — mpv の独立化

**対象:** `nix/modules/home/programs/mpv/default.nix`（新規）、`nix/modules/home/features/media.nix`。

- `media.mpv.settings` を Program に移し、`autofit-large` を `autofit-larger` に修正する。旧オプションは移行先を示すエラーにする。
- `programs.mpv.finalPackage` を実効実行ファイルとして扱い、`scripts` や package 上書きも反映する。
- 生成 `mpv.conf` の読み込み結果について、終了コードだけでなく `Error parsing option` を検査する。単独利用と `package = null` も確認する。

## Phase 2 — Browser 選択・提供

**対象:** `nix/modules/home/features/desktop-integration/`、`nix/modules/home/programs/{glide,firefox,qutebrowser,krita}/`、`nix/modules/home/programs/niri/`、GUI Profile、`media.nix`。

- Browser Provider と `desktopIntegration.browser.selected` を導入。Linux GUI では `lib.mkDefault "glide"` とし、Media の旧 Browser 提供と**同時切替**する。同じ変更で `media.programs` 由来の Krita を `media.graphics.krita.enable` へ移し、Linux GUI に Krita が残り、TTY では Media から要求されないことを検証する。
- Niri の固定 Glide 起動を選択 Provider のコマンドに置き換える。desktopIntegration OFF、選択 `null`、Niri 単独の各構成で起動行を検証する。
- Linux では新 Provider から Browser 4関連付けを生成する。既定アプリ API の部分上書きと競合検出を確認する。
- Darwin の Glide・ff2mpv 旧経路は維持する。Linux で無効になった `media.programs` の明示設定は移行エラーにする。

## Phase 3 — 機能 API と Linux adapters

**対象:** `nix/modules/home/features/media.nix`、`desktop-integration/{mime-apps,portal,termfilechooser}.nix`、Browser 共通設定、関連テスト。

- `media.mimeApps` と `desktopIntegration.mimeApps` を `fileAssociations` の機能 API へ移す。公開値のアプリ識別と XDG Desktop Entry を内部で変換する。任意 MIME 型の Host 上書きは機能 API または明示した実装固有設定へ移行できるようにする。
- `desktopIntegration.fileChooser.{enable,mode}` を追加。Linux の `auto` は Terminal ありなら termfilechooser、なしなら GTK とする。`enable = false` は FileChooser の寄与だけを停止し、他の Portal 設定と外部 chooser／package を残す。旧 `backend = null` の外部 chooser テストを新 API でも成立させる。`portal.*` の詳細設定は実装固有として整理する。
- Linux の Web Playback adapter を Browser 別に構成する。録画用 `finalPackage` に URL が届くこと、OFF／Browser 切替後に Media 由来の連携設定が残らないことを確認する。
- Home Manager が `video/*` を具体 MIME 型に展開することを利用し、mpv 固定の `video/mp4` 規則は重複追加しない。論理ハンドラーを変更したとき `video/mp4` も追従することを、競合するシステム規則を持つ隔離 XDG 環境で照会する。`mpv.desktop` の存在も別途検証する。
- TTY では GUI 固有の関連付けを既定 OFF にし、従来のホストテストを更新する。Terminal 不在の FileChooser `auto` は成功、明示 `terminal` はエラーとする。**GUI Profile を取り込まない Media-only Home**（Terminal OFF）で desktopIntegration の自動有効化と GTK 選択を確認する。
- `media.firefoxIntegration` の Linux 旧設定を移行し、Darwin では既存の経路を維持する。

## Phase 4 — Darwin adapters と旧経路撤去

**対象:** `desktop-integration.nix`、`desktop-integration/org-protocol.nix`、関連付け／FileChooser の内部 adapter、GUI Profile、`media.nix`、Browser Program、Darwin Home テスト、`nix/ci/default.nix`。

- Darwin GUI にも Browser = Glide、Web Playback = ON の機能的な既定動作を適用する。Browser 提供は新 Provider、URL 転送は最終 mpv、ファイル選択は利用可能な macOS 標準機構を利用する。
- XDG Portal・XDG MIME・termfilechooser を Darwin の共通機能として起動しない。`orgProtocol.enable` は Darwin の対応実装ができるまで既定 OFF、明示 ON は理由付きエラーとし、XDG Desktop Entry を生成しない。対応する機能は Darwin adapter で実装し、macOS の関連付け保証には実効照会テストを要求する。
- **Darwin の2ホスト×2テーマ＝4 Home 構成**で `Glide.app`、使用プロファイルの ff2mpv 拡張、manifest の `allowed_extensions` と拡張 ID の一致、Glide 連携から `programs.mpv.finalPackage` への URL 到達を検証してから、`media.programs`・`media.firefoxIntegration` の旧経路を同時撤去する。通常 PR CI の代表 Home 1件だけでは承認しない。
- 旧 `mimeApps`／FileChooser backend の明示設定は、機能別 API への変換または移行エラーで扱い、無効な旧設定を黙って無視しない。


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

`nix/tests/home/desktop-integration.nix`、`nix/tests/home/desktop-integration-mime.nix`、`nix/tests/system/desktop-integration.nix`、Niri／Darwin／Media テストを更新して `nix/checks.nix` に登録する。

各 Phase で Linux GUI・TTY・Darwin GUI の既存構成と実効出力を検証する。**テストは機能別に整理し、OS 別ケースは内部実装の差異を検証するために用いる。** `flake check` と整形環境由来の失敗は区別して記録する。
