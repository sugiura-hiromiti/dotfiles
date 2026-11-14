# desktopIntegration — 実装・検証記録

対象: [責務整理の実装計画](../plans/2026-11-14-desktop-integration-responsibility-refactor.md)。
Task 1–2 の既存作業を引き継ぎ、2026-11-15 に Task 3–6 を実装した。

## 根本原因と変更

- FileChooser の選択、Backend 登録、wrapper 配布は `portal.fileChooser.backend` 一つから導出する。`"termfilechooser"` / `"gtk"` / `null` を受け付け、旧 `portal.fileChooserBackend` / `termfilechooser.enable` は移行先を示すエラーにする。Host / Profile に旧 API の明示利用はなかった。
- daemon が端末 argv を展開した後に wrapper 内で `TERMCMD` を設定しても端末を選択できない。wrapper は六つの FileChooser 入力を保持し、後続 argv を実効 Terminal Provider の待機コマンドへ置換する。Terminal の無効化は選択時だけ説明的な assertion とし、自動有効化はしない。
- `termfilechooser.package`、Yazi 互換の `fileManager.package`、選択された Terminal package を実際の起動・PATH に反映する。Yazi Program 自体の有効化は不要。
- NixOS の無条件 Keyring 要求を削除した。既存 GUI は Niri が提供する Keyring を維持する。Home の Default / Access / Notification / Secret は外部実装への選択 Policy と明記し、公開値と最終 Portal 設定の矛盾を検出する。
- MIME は既存の選択方針を維持する。Glide は Qutebrowser より優先され、directory / URI は Yazi が既定。Host の明示 map は自動 map 全体を置換する。任意の MIME ハンドラーの導入・検証は各 Program / session の責務。
- Org Protocol は独立に有効な Emacs を使って desktop entry を登録する。MIME 既定化とは別に制御でき、カスタム Emacs package を尊重する。

## 最終レビューでの追加修正

Alacritty の Provider が返す通常起動コマンドには、子コマンド用の `-e` が含まれていなかった。[公式 CLI](https://alacritty.org/cmd-alacritty.html) と実際の Provider / 上流 Yazi wrapper の呼び出しを確認し、実際の組み込み Provider 定義を使う回帰テストで失敗を再現した。

Provider の `mkCommand` に任意の `withCommand` 引数を追加した。既定は `false`、chooser だけが `true` を渡し、Alacritty は末尾に `-e` を追加する。WezTerm は拡張引数を受け入れる。Kitty / WezTerm の起動形式と Niri の通常起動は維持する。閉じた引数集合を持つ外部のカスタム Provider は `withCommand` を受け付ける必要がある。

これは Terminal の再設計ではなく、Task 3 が保証する Provider 交換を成立させるために必要な変更。実際の Provider 定義と GUI 起動先の記録用プロセスで、Kitty / Alacritty / WezTerm の chooser 起動と通常起動を検証した。修正前の Alacritty は終了コード 94、修正後は成功した。

## 専用 checks

`nix/checks.nix` に Linux 用の五つの check を登録した。

| Check                         | 検証範囲                                                                                                                  |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `desktop-integration-home`    | 独立 Home 評価、Backend / Package 上書き、無効化、共有 Portal / Keyring、移行・依存・最終設定の診断                       |
| `desktop-integration-nixos`   | 独立 NixOS 評価、Niri との優先順位、共有資源、Backend 導入、移行・矛盾の診断                                              |
| `desktop-integration-wrapper` | 固定済み上流 Yazi wrapper の実行、四つの選択モード、六つの入力と引用符、Package / PATH 上書き、実際の三種の Provider 定義 |
| `desktop-integration-mime`    | Browser / Emacs 条件、Host map 置換、無効化・共有、生成 desktop / MIME ファイルと emacsclient の URL argv                 |
| `desktop-integration-hosts`   | standalone Home 8、NixOS 12、内包 Home 12。両 CPU、GUI / TTY、light / dark、X12 native と Parallels / QEMU                |

各テストの直接 import による独立 build と、登録後の五件をまとめた最終 build が成功した。

再現コマンド:

```sh
XDG_CACHE_HOME=/tmp/desktop-integration-cache direnv exec . nix build --no-link \
  path:.#checks.x86_64-linux.desktop-integration-home \
  path:.#checks.x86_64-linux.desktop-integration-nixos \
  path:.#checks.x86_64-linux.desktop-integration-wrapper \
  path:.#checks.x86_64-linux.desktop-integration-mime \
  path:.#checks.x86_64-linux.desktop-integration-hosts
```

Home / NixOS の最小テストは負例でも全 assertion を強制評価する。Host テストの内包 Home は source 位置から対象 Feature の assertion を選ぶ。standalone Home の公開 config は上流 Home Manager 自身が全 assertion を検証するため、無関係な Theme の評価時 build が必要になる場合がある。今回の直接 Host テストでは必要な source の取得が成功した。

## 2026-11-15 時点の検証と制約

- 変更した Nix の `nixfmt --check`、リポジトリ全体の `statix check .` / `deadnix --fail .` が成功。
- 全体の treefmt check は既存 `glide.ts:517` のインデント一か所で失敗。Nix build の隔離環境で確認し、元の利用者編集は変更していない。
- X12 GUI の system toplevel dry-build と実 build が成功。内包する no-gui 構成と Home generation も build 済み。結果は `/nix/store/lnyhqgj1yp0ywvcdqp4kma2xsndz1w5p-nixos-system-thinkpad-x12-26.11.20261111.d4f25a3`。システムには反映していない。
- 既存 `session-gui-nixos` / `session-gui-home` / `session-gui-hosts` の三件の flake build が成功。前回の Task 2 で取得できなかった Alacritty 等も今回は substitute された。
- 全体の `nix flake check --no-build` は installer-e2e の `disko.drv` 無効参照で失敗。`--option eval-cache false` による installer-e2e 単独評価は成功し、同条件での全体再評価では全専用 checks・installer-e2e・non-vm 集約の評価を通過した。その後 `aarch64-linux-a--deployment-parallels--theme-dark--session-gui` の `console.colors` 評価で `/nix/store/m66nwvmqbkppfb7lifp5riib9s714kag-catppuccin-palette-0-unstable-2026-03-21.drv` が無効とされ失敗。全体評価の成功は主張しない。store / 評価状態の原因までは特定しておらず、今回変更していない依存 Package や lock の更新で回避していない。
- 最初の長時間チェックは作業再開時に実行セッションが終了した。上記の成功・失敗は、その後に結果を取得できた再実行の記録。
- 実機での Portal / D-Bus 起動、GUI の表示・終了待機、Keyring のログイン解除は未検証。外部提供の non-FileChooser Backend / MIME ハンドラーと互換でない代替 package の実行可能性を保証しない。
- Home Manager と NixOS は独立した API。Host 行列では既存 Profile の整合した既定値を検証し、両者の自動同期を追加していない。
- `.git` が読み取り専用のためコミットは作成していない。既存の未公開 jj change を引き継いでおり、Emacs / Glide の利用者編集には手を加えていない。

## その後の調査と恒常的な対処

上記の Catppuccin エラーは、`flake check --no-build` の読み取り専用評価と、評価中に配色データを読み込む IFD の組み合わせと確認した。[Nix の実装](https://github.com/NixOS/nix/blob/master/src/nix/flake.cc#L339-L344)でも `--no-build` 時に読み取り専用モードになる。

失敗した aarch64 構成の `console.colors` を `nix eval --read-only --option eval-cache false` で単独評価すると、同じ palette `.drv` の無効参照を再現できた。`--read-only` を外した通常評価で Catppuccin キャッシュから palette を取得し、同じ読み取り専用評価が成功した。対象の `toplevel.drvPath` の通常評価後、全体の `nix flake check --no-build --no-update-lock-file --option eval-cache false path:.` も exit 0 になった。依存更新や store 修復は行っていない。

利用者の選択に従って専用の評価 app と専用テスト・設計文書を削除し、今後は標準の `nix flake check --no-update-lock-file path:.` で検証する。`--no-build` は付けず、必要な依存と checks の build を許可する。方針は [AGENTS.md](../../../AGENTS.md) と README に記録した。Linux CI は導入前の評価＋non-VM build を維持し、Nix バージョン互換性 CI は評価だけを行う。

2026-11-16 に `XDG_CACHE_HOME=/tmp/desktop-integration-cache direnv exec . nix flake check --no-update-lock-file --print-build-logs path:.` を実行し、exit 0 と `all checks passed!` を確認した。実行システムは x86_64-linux。公開 NixOS 12 構成の評価は Catppuccin palette の取得を含めて成功し、整形検査と登録済み checks の build・VM 検査も通過した。以前の treefmt 失敗は上記の過去時点の記録であり、今回の全体 treefmt は変更 0 件だった。異なるシステムの per-system checks は標準動作で除外されており、Darwin / aarch64 checks の build 成功は主張しない。ログは `/tmp/dotfiles-remove-check-flake-check.log`。
