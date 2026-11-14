# desktopIntegration — Task 1 調査・契約の基準

対象: [実装計画](../plans/2026-11-14-desktop-integration-responsibility-refactor.md) の Task 1。
記録日: 2026-11-14。実装変更前の調査であり、Portal の実機動作確認ではない。

## 調査元と利用箇所

- 開始時の `jj status` は変更なし。working change は `xwoskuol` / `33eb7dc4`、親は `main` / `73ee6ffd`。この未公開 change を使用し、`main` は移動しない。
- `flake.lock` の root `nixpkgs` は `d4f25a3e562008648d45bcf2d70bcc7422cad84e`、Home Manager は `82ce401aa350502897c3f2e85f384d61cd3b0b6d`。
- 固定済みバージョンは Portal 1.22.1、termfilechooser 1.5.0、GTK backend 1.15.3、GNOME backend 51.0、GNOME Keyring 50.0、Niri 26.04。
- `rg -n 'desktopIntegration|fileChooserBackend|termfilechooser|xdg\.portal|orgProtocol|mimeApps' nix` とリポジトリ全体の Feature 名検索を実施した。
- 公開 API の利用側は `nix/profiles/variants/desktop-integration/{home,nixos}.nix` の `enable` のみ。旧 `fileChooserBackend` / `termfilechooser.enable` を明示指定する Host はない。
- `nix/runtime-contexts.nix` は GUI に `desktop-integration` Profile を追加し、TTY には追加しない。Home と NixOS の Profile は独立に `hasGui && isLinux` を既定値にする。

## 実効値の基準

[評価用 probe](2026-11-14-desktop-integration-baseline.nix) で既定 Theme `light` の以下を評価した。

Task 2 以降の probe は現行 API の `portal.fileChooser.backend` を出力し、削除した `termfilechooser.enable` は参照しない。以下の表と旧オプションの記述は Task 1 時点の観測記録。

- standalone Home: `x86_64-linux-a` / `aarch64-linux-a` × `gui` / `tty` の 4 Target。
- NixOS: X12 `native`、aarch64 `parallels` / `qemu` × `gui` / `tty` の 6 Target。
- 上記 NixOS 内包 Home の 6 構成。関連する値は同じ Host / session の standalone Home と一致した。

| 観測対象                                 | GUI                                        | TTY          |
| ---------------------------------------- | ------------------------------------------ | ------------ |
| NixOS / Home `desktopIntegration.enable` | `true`                                     | `false`      |
| NixOS / Home `xdg.portal.enable`         | `true`                                     | `false`      |
| NixOS `extraPortals`                     | termfilechooser、gnome-keyring、gnome、gtk | 空           |
| Home `extraPortals`                      | termfilechooser のみ                       | 空           |
| NixOS GNOME Keyring service              | `true`                                     | `false`      |
| Home GNOME Keyring service               | `false`                                    | `false`      |
| Home の termfilechooser 設定ファイル     | あり                                       | なし         |
| Home の `org-protocol.desktop`           | あり                                       | なし         |
| Terminal / Provider                      | 有効 / Kitty                               | 有効 / Kitty |
| Yazi / Emacs / Glide                     | 有効                                       | 有効         |

TTY でも子オプション `termfilechooser.enable` / `orgProtocol.enable` の値は `true` だが、親 Feature が無効なので配布はない。子の値だけを配布の証拠にしない。
`xdg.mimeApps.enable` は TTY でも media Feature により `true`。`audio/*`、`image/*`、`video/*` の MPV 関連付けが残る。

GUI の system / Home は同じ `niri-portals.conf` の内容を生成した。

```ini
[preferred]
default=gnome;gtk
org.freedesktop.impl.portal.Access=gtk
org.freedesktop.impl.portal.FileChooser=termfilechooser
org.freedesktop.impl.portal.Notification=gtk
org.freedesktop.impl.portal.Secret=gnome-keyring
```

GUI の MIME は directory / URI list が `yazi.desktop`、plain text が `emacsclient.desktop`、HTTP / HTTPS / HTML / XHTML が `glide.desktop`、Org Protocol が `org-protocol.desktop`。
Org の entry は実効 `programs.emacs.finalPackage` の `emacsclient -n -r -- %u` を使用する。現 Target は Qutebrowser 無効、Glide 有効なので、両方有効時の後勝ちは Task 5 の独立テスト対象。

## Portal の生成・探索・優先順位

固定 Nixpkgs の `nixos/modules/config/xdg/portal.nix` は `/etc/xdg/xdg-desktop-portal/<configName>-portals.conf`、固定 Home Manager の `modules/misc/xdg/portal.nix` は `$XDG_CONFIG_HOME/xdg-desktop-portal/<configName>-portals.conf` を生成する。
`configName = "common"` は両方とも `portals.conf` になる。

Portal 1.22.1 の `src/xdp-portal-config.c:467–507,538–587,863–895` を確認した。
取得した Portal / Niri の source tree hash も固定 Nixpkgs の `src` の hash と照合した。Portal は `sha256-GYPc5gFw3vMiDbrw5h6xeU7wupfyWeWq/Vl+vVrX8h0=`、Niri は `sha256-ehSMsSpE+0k8r+2Vseu8kangsYxToZv3vinynsDp9zs=`。

1. 通常は XDG config home、config dirs、コンパイル時 sysconfdir、XDG data home、data dirs、コンパイル時 datadir の順に設定を読む。
2. 各ディレクトリ内では `XDG_CURRENT_DESKTOP` に対応する desktop 別設定を先に探し、なければ `portals.conf` を読む。
3. 各設定の interface 固有指定、同じ設定の `default`、次の優先順位の設定という順に、存在し対象 interface を提供する backend を探す。
4. したがって Home の設定が優先されるが、上位の設定ファイル一つで探索が全面終了するわけではない。backend が欠落・非対応なら下位へ進める。`none` の明示指定は別の停止条件。
5. `XDG_DESKTOP_PORTAL_DIR` の環境上書きがある場合は通常の探索を置き換える。実機の環境・D-Bus 起動条件は未検証。

Niri 26.04 の `src/main.rs:93–96,215–217,276–310` は session 起動時に `XDG_CURRENT_DESKTOP=niri` を設定し、systemd / D-Bus に環境を取り込む。
`configName` の上書きはデスクトップ名そのものを変更しない。別名を指定する場合は実際の session 名に対応させるか `common` を使う責任がある。

Home Manager の option 説明には `NIXOS_XDG_DESKTOP_PORTAL_CONFIG_DIR` が残るが、実装は `xdg.configFile` に生成する。
また Home Manager は `NIX_XDG_DESKTOP_PORTAL_DIR` を設定するが、固定済み Portal の探索コードはこの変数を参照しない。これらの変数による system / Home の上書きを保証根拠にしない。

### Backend と共有資源の所有者

- NixOS の Niri module は `gnome` backend を追加し、共通 Wayland session module が `gtk` を追加する。`nix/modules/nixos/features/session-gui.nix` は `programs.niri.useNautilus = false` を指定する。
- Niri module はその場合 `config.niri.FileChooser = "gtk"` を通常優先度で定義する。現 Feature の `mkForce` はこの具体的な競合に対応する。単に削除すると既定 GUI の合成が競合する。
- `gtk.portal` / `gnome.portal` / `termfilechooser.portal` / `gnome-keyring.portal` が backend 識別子を決める。GTK と GNOME は FileChooser を提供するが、GNOME の FileChooser には Nautilus が必要と Niri module に明記されている。
- Niri module は GNOME Keyring を `mkDefault true` にする。Keyring service module は daemon / D-Bus activation / PAM login と Secret Portal を提供し、`xdg.portal.extraPortals` にその package を追加する。
- 現 desktopIntegration の無条件 Keyring 要求は既定 GUI では Niri の要求と重複する。Secret backend の名前を指定するだけで daemon / unlock / service が提供されるわけではない。
- Home の現 Feature が導入する backend は termfilechooser のみ。Home 単独では `gnome` / `gtk` / `gnome-keyring` の提供を保証していない。

## termfilechooser の実際の呼び出し契約

Nixpkgs の package は v1.5.0 の `contrib/yazi-wrapper.sh` を変更せず配布する。取得した source の `nix hash path` は package の固定値 `sha256-U3Fv6Q8HYQEi8rZfGUJCEMVxZwxtpQNIAwctKWDyjZw=` と一致した。

- `src/filechooser/filechooser.c:88–105,140–145,180–199`: daemon が環境の `TERMCMD` を展開し、wrapper の六つの入力（multiple / directory / save / path / output / debug）の後ろに端末の argv を付加する。wrapper の終了を待ってから結果ファイルを読む。
- `contrib/yazi-wrapper.sh:6–13,21–40`: 六つの入力を取り出し、残りの argv を端末コマンドとして `yazi` と一緒に起動する。環境の `TERMCMD` は読まない。
- 現 Home wrapper は起動後に `TERMCMD` を export するため、daemon の端末選択に間に合わない。生成物でも確認した。Provider の PATH が含まれているだけでは、選択した端末が使われることを保証しない。
- `contrib/config:7` は daemon 側の `env=TERMCMD=...` を例示する。ただし `config.c` の環境設定と daemon のコマンド処理で展開が重なるため、空白や引用符を含むコマンドの扱いをテストせず採用しない。Task 3 では六つの入力と端末 argv の境界まで検証する。
- wrapper は `yazi --chooser-file=...` を使い、directory では `--cwd-file=...` も使う。外部コマンドは Yazi、`cat`、`rm`。`gnused` はこの wrapper 自体では使っていない。
- `fileManager.package` の交換範囲は、この CLI を提供する `bin/yazi` を持つ互換 package。任意の File Manager を交換できる API ではない。`programs.yazi.enable` は wrapper の必須条件ではない。
- Kitty Provider は通常の foreground 起動を生成し、`wait` を明示的に参照しない。WezTerm Provider は `wait = true` で `start --always-new-process` を付ける。Provider の変更時は最終コマンドと package を検証する。GUI を実際に閉じるまでの待機は未検証。

## 次の Task で実装する契約

1. 公開値は `portal.fileChooser.backend` 一つにする。初期サポートは `null` / `"termfilechooser"` / `"gtk"`、既定値は `"termfilechooser"`。既存 GUI の選択を維持し、GTK を端末不要の交換可能な backend として提供する。
2. `termfilechooser` / `gtk` を選んだターゲットがその package・Portal 登録・interface 選択を要求する。NixOS は system 側の engine と登録・選択、Home は user 側の engine と登録・選択に加え termfilechooser のユーザー設定と wrapper を担当する。NixOS 単独で Home の Terminal API を参照せず、ユーザーの chooser / 端末設定は別途必要と明記する。
3. `null` は専用 FileChooser 指定と管理 backend の追加を止める。共有の `default` や他 module による FileChooser 選択・導入は残り得る。`portal.enable = false` はこの Feature の Portal / wrapper 寄与を、親 `enable = false` は全寄与を止める。
4. 任意 backend 名の自動解決、GNOME FileChooser の Nautilus 構成は追加しない。外部 backend を使いたい場合は `null` と下位 `xdg.portal` API を組み合わせ、提供責任を呼び出し側が持つ。
5. FileChooser 以外の `defaultBackends` / Access / Notification / Secret は session / system が提供する backend への選択 Policy として扱う。Home の単独有効化だけでそれらの daemon / unlock を提供するとは約束しない。FileChooser の管理対象の保証と区別して option 説明・テストに記す。
6. Task 4 では desktopIntegration の重複した無条件 Keyring 要求を除き、既存 GUI では Niri の要求を残す。Keyring を新 Feature に分離しない。共有資源を強制無効化しないことをテストする。
7. termfilechooser を必要とする Home のみ Terminal Provider を必須にし、欠落は説明的な契約エラーにする。端末を自動選択しない。package 上書きは互換 CLI を提供する責任を持ち、実際の起動 argv / PATH で検証する。
8. 旧二重 API を削除・移行し、旧 option が黙って無視される互換層は作らない。現 Host の明示利用はない。MIME / Org は Task 5 で独立に扱う。

## 再現と検証の範囲

リポジトリ root で実行する。

```sh
XDG_CACHE_HOME=/tmp/desktop-integration-cache direnv exec . \
  nix eval --offline --impure --json \
  --file docs/superpowers/evidence/2026-11-14-desktop-integration-baseline.nix \
  > /tmp/desktop-integration-baseline.json
```

評価は上記の構成断面と生成予定の設定 text / wrapper 参照を取得する。全 assertion、activationPackage、system toplevel、実機の D-Bus 応答を検証するものではない。
`--offline` でも既存構成の NUR 参照が GitLab の source 取得を開始したため、cold cache で完全なオフライン再現は保証しない。今回の評価は取得後に成功した。

未実施: dark Theme、Darwin、全チェック・Host build、Portal の起動・FileChooser の GUI 操作、Keyring のログイン解除。Task 2 以降で最小の失敗テストから実装し、Task 6 で契約行列と Host 検証を行う。
