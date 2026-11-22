# Media / desktopIntegration リファクタリング実装計画

**前提:** [設計仕様](../specs/2026-11-21-media-desktop-integration-design.md)

## Phase 1 — mpv の独立化

**対象:** `nix/modules/home/programs/mpv/default.nix`（新規）、`nix/modules/home/features/media.nix`。

- `media.mpv.settings` を Program に移し、`autofit-large` を `autofit-larger` に修正する。旧オプションは移行先を示すエラーにする。
- `programs.mpv.finalPackage` を実効実行ファイルとして扱い、`scripts` や package 上書きも反映する。
- 生成 `mpv.conf` の読み込み結果について、終了コードだけでなく `Error parsing option` を検査する。単独利用と `package = null` も確認する。

## Phase 2 — Browser 選択・提供

**対象:** `nix/modules/home/features/desktop-integration/`、`nix/modules/home/programs/{glide,firefox,qutebrowser,krita}/`、`nix/modules/home/programs/niri/`、GUI Profile、`media.nix`。

- **旧経路の撤去前に**、Terminal 不在で FileChooser が GTK を選ぶ暫定的な `auto` 相当の既定値と、セッション不明時の FileChooser 専用共通 Portal 設定を実装する（正式な `fileChooser` API への移行は Phase 3）。GUI Profile を使わない Media-only Home（Terminal OFF）で desktopIntegration が自動 ON、Glide と GTK が実効的に提供されることを確認する。**このテストを満たす同じ変更で** Browser Provider と `desktopIntegration.browser.selected` を導入し、Linux GUI 既定を `lib.mkDefault "glide"` に移す。Media 旧 Browser 提供の撤去を先行しない。同じ変更で Krita を `media.graphics.krita.enable` に移し、Linux GUI で提供、TTY では要求なしを確認する。
- Niri の固定 Glide 起動を選択 Provider のコマンドに置き換える。desktopIntegration OFF、選択 `null`、Niri 単独の各構成で起動行を検証する。
- Linux では新 Provider から Browser 4関連付けを生成する。ただし Phase 2 中は **旧 `mimeApps.defaultApplications` の全置換 semantics を変更しない**。**desktopIntegration 単独**で `inode/directory` だけを指定した場合は、同 Feature の関連付け寄与が1件であることを検証する。**Media 併用**ではそのディレクトリ設定と Media の `video/mp4` 等の関連付けがともに最終 `mimeapps.list` に残ることを確認する（展開後の総件数は固定しない）。新 API の部分上書きは別途検証する。
- Darwin の Glide・ff2mpv 旧経路は維持する。Linux で無効になった `media.programs` の明示設定は移行エラーにする。

## Phase 3 — 機能 API と Linux adapters

**対象:** `nix/modules/home/features/media.nix`、`desktop-integration/{mime-apps,portal,termfilechooser}.nix`、Browser 共通設定、関連テスト。

- `media.mimeApps` と `desktopIntegration.mimeApps` を `fileAssociations` の機能 API へ移す。旧 MIME の明示的な全置換値は機械的に部分合成へ変換せず、**`fileAssociations.autoDefaults.enable = false` と明示規則**への移行先を示してエラーにする。ディレクトリ1件の旧設定と新設定の生成結果が一致すること、および新 API の通常の部分上書きが動くことを別々に検証する。任意 MIME 型の Host 上書きも移行できるようにする。
- `desktopIntegration.fileChooser.{enable,mode}` を追加し、Phase 2 で導入した Terminal 不在時の GTK 選択を正式な `auto` に移す。`enable = false` は FileChooser の寄与だけを停止し、他の Portal 設定と外部 chooser／package を残す。外部から `FileChooser=gtk` と対応する `xdg-desktop-portal-gtk` を与え、Feature 由来の chooser がなく、**実効的に GTK が選ばれる**ことを確認する。`FileChooser=external` の設定値だけを確認する従来のテストでは不十分。`portal.*` の詳細設定は実装固有として整理する。
- Linux の Web Playback adapter を Browser 別に構成する。既定値は選択 Browser・対応 adapter・実効 mpv の成立に従う。Browser あり＋mpv 不在 → 既定 OFF、同条件で明示 ON → エラー、独立 mpv 提供 → 既定 ON を検証する。録画用 `finalPackage` への URL 到達と、OFF／Browser 切替後の Media 由来設定が消えることを確認する。**Firefox の新規プロファイルで ff2mpv が自動的に有効化され、ブラウザー操作から URL を送れること**を受入条件とし、native host 直接呼び出しだけで済ませない。**Qutebrowser を選択した場合は `,m` から現在の URL が `programs.mpv.finalPackage` に届くこと**もテストする。
- Home Manager が `video/*` を具体 MIME 型に展開することを利用し、mpv 固定の `video/mp4` 規則は重複追加しない。論理ハンドラーを変更したとき `video/mp4` も追従することを、競合するシステム規則を持つ隔離 XDG 環境で照会する。`mpv.desktop` の存在も別途検証する。
- TTY では GUI 固有の関連付けを既定 OFF にし、従来のホストテストを更新する。Terminal 不在の FileChooser `auto` は成功、明示 `terminal` はエラーとする。Phase 2 で追加した **GUI Profile なし・Terminal OFF の Media-only GUI Home** の Glide／GTK／desktopIntegration テストを維持し、Phase 3 では Web Playback の実効提供と Browser 明示 `null` 時の無寄与まで確認する。
- Phase 2 の共通 Portal 設定を受入テストで再検証する。セッション不明時は共通 `portals.conf` に **`org.freedesktop.impl.portal.FileChooser=gtk` のみ**を寄与し、`default`・`Inhibit` 等は変更しない。Niri 固有の既存ポリシーは `niri-portals.conf` に保持する。隔離 D-Bus セッションで `XDG_CURRENT_DESKTOP=sway`、Sway 側 `Inhibit=none` に対し **FileChooser=gtk と Inhibit=none が同時に成立**することを検証する。
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
