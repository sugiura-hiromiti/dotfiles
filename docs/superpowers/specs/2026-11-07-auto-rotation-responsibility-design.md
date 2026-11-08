# Auto Rotation Responsibility Refactor — Design Specification

**Status:** 実装用設計案（ユーザーとの議論で合意した責務方針に基づく）。実装・テストは未実施。\
**Repository:** `sugiura-hiromiti/dotfiles`\
**Evidence baseline:** GitHub `main` commit `bba6208291ac2f9ca573cd8829c9e58d0a50aae9`。実装時にはローカル HEAD と差分を再確認すること。

## Intent

リポジトリ全体で採用する責務モデルを、まず **`autoRotation` のみに適用する**。Host は「自動回転を使うか」とハードウェア固有の識別情報を宣言し、Feature は実現手段と関連する設定の有効・無効を所有する。これにより、同じ機能を別 Host に導入しても `iio-niri` の CLI 引数や udev ルールを複製せずに済む。

この作業の目的は抽象化の削減でも既存挙動の無条件保存でもなく、**責務分離・一貫性・設定の局所性**。One step at a time を守り、他の Feature や Variant 廃止には着手しない。

## Current state

- `nix/modules/nixos/features/auto-rotation.nix`: `dotfiles.features.autoRotation.enable` を定義し、有効時に `services.iio-niri.enable = true` のみ設定。
- `nix/profiles/hosts/x86_64-linux-a/nixos.nix`: `autoRotation.enable = true` に加え、`services.iio-niri.extraArgs = [ "--monitor" "eDP-1" ]` と `accel_3d` 用 udev ルールを直接設定。
- `nix/modules/nixos/default.nix`: Feature を明示 import。
- Git の履歴では、udev ルールは 2026-10-18 の「自動回転修正」で追加された。ただし、他機能でもそのルールを必要とするかどうかは履歴だけでは確定できない。
- ロックされた Nixpkgs `1d060086d60cb76a40cf37109f979d88a5bd6396` の `services.iio-niri.enable` は IIO センサー有効化、ユーザー systemd サービス等を自動で構成する。Feature 側でこれらを再実装しない。

## Goals

1. Host は `dotfiles.features.autoRotation` の公開オプションのみを通じて自動回転を宣言する。
2. Feature は `services.iio-niri.enable` と `extraArgs` をまとめて構成する。
3. 自動回転専用であると確認できた udev 回避策は Feature が構成し、無効化時には適用しない。
4. Host は `eDP-1` と `accel_3d` などハードウェア固有の事実だけを渡す。
5. Feature の有効・無効、回避策の有無、別 Host の値を Nix 評価で検証する。

## Non-goals / anti-goals

- Variant 全廃、`osk`・`dtm` 等の再設計、Runtime 整理、Home Manager との統一制御、ディスプレイ識別子の全リポジトリ共通化。
- Nixpkgs の `services.iio-niri` が行う systemd/IIO 構成の再実装。
- Feature 有効化が `niri` のインストール・起動自体を所有するという拡大解釈。
- 単にファイルを移動すること、行数削減、動作を無条件に維持することを目的化しない。
- 他の機能に必要な udev ルールを Feature の無効化で消すことは避ける。

## Chosen approach and alternatives

- **採用：Feature API を拡張する。** Host は機能と機器情報を指定し、Feature は iio-niri の具体的な構成を生成する。依存方向は Host → Feature API → Nixpkgs module。
- **不採用：Host から `services.iio-niri` を直接設定する。** 独自コードは少なくなるが、Host が実現方法を知るため責務が漏れる。
- **今回対象外：汎用ハードウェア・センサー抽象化の新設。** センサー設定が複数 Feature に共有される事実が見つかった場合のみ、個別の設計判断を行う。

## Public interface (NixOS)

```nix
# Host の自動回転関連設定の完成イメージ
dotfiles.features.autoRotation = {
  enable = true;
  monitor = "eDP-1";
  pollingSensorName = "accel_3d";
};
```

- `enable`: `bool`、既定 `false`。その Feature 自身が生成する設定を制御する。
- `monitor`: `nullOr nonEmptyStr`、既定 `null`。`enable = true` の場合は非 null を必須とし、欠落時は説明的な NixOS assertion で失敗させる。`enable = false` では不要。
- `pollingSensorName`: `nullOr str`、既定 `null`。`null` は追加の udev 回避策が不要であることを示す。指定された場合は IIO センサー名として取り扱い、`^[A-Za-z0-9_.-]+$` に一致しない値を拒否する（udev ルール文字列への安全な埋め込みのため）。

## Ownership / behavior contract

- **Host**: `enable` の意思決定、回転対象 `monitor`、対象センサーの識別情報／回避策が必要かというハードウェア特性。
- **Feature**: `services.iio-niri.enable`、`services.iio-niri.extraArgs` の生成、自動回転専用 udev ルールの生成。`enable = false` ではこの Feature による定義を追加しない。
- **Nixpkgs**: iio-niri の package、IIO センサー対応、systemd user service の詳細。
- **Shared ownership**: 同じ service が別のモジュールから有効化されていれば、Feature の無効化は他者の定義を強制的に消さない。

### udev ルールの判断ゲート

実装前にリポジトリ全体とコミット履歴で `accel_3d` / `IIO_SENSOR_PROXY_TYPE` を調査すること。現在の履歴は自動回転との関連を支持するが、**他機能でも必要とする証拠が見つかったら、無条件に Feature へ移さない**。その場合は Host 側にハードウェア設定として残す案を報告し、責務境界の判断を求める。根拠が見つからなければ「現時点では自動回転専用と扱う」という前提を明記した上で Feature へ移行する。

## Acceptance criteria

- X12 Host に `services.iio-niri.extraArgs` と自動回転専用の udev ルールが直接残らない（上記判断ゲートで共有設定と判定された場合を除く）。
- `enable = true`, `monitor = "eDP-1"`, `pollingSensorName = "accel_3d"` → iio-niri 有効、引数一致、該当 udev ルールが生成される。
- `enable = false` → Feature 自身の iio-niri / udev 定義が適用されない。監視する設定の存在/非存在は独立した最小 NixOS 評価で確認する。
- `enable = true`, `monitor = "eDP-1"`, `pollingSensorName = null` → iio-niri が有効、udev 回避策は生成されない。
- `enable = true` で `monitor` 未設定 → 適切な assertion が失敗する。
- 別 Host を想定した異なる `monitor` / `pollingSensorName` で同じ Feature を構成でき、Host 側に実装詳細が不要。
- 既存の X12 NixOS 評価が通る。実機での回転動作確認が可能なら実施、不可なら未検証と明記。

## References

- [Feature](https://github.com/sugiura-hiromiti/dotfiles/blob/bba6208291ac2f9ca573cd8829c9e58d0a50aae9/nix/modules/nixos/features/auto-rotation.nix)
- [X12 Host](https://github.com/sugiura-hiromiti/dotfiles/blob/bba6208291ac2f9ca573cd8829c9e58d0a50aae9/nix/profiles/hosts/x86_64-linux-a/nixos.nix)
- [NixOS module imports](https://github.com/sugiura-hiromiti/dotfiles/blob/bba6208291ac2f9ca573cd8829c9e58d0a50aae9/nix/modules/nixos/default.nix)
- [Pinned Nixpkgs iio-niri](https://github.com/NixOS/nixpkgs/blob/1d060086d60cb76a40cf37109f979d88a5bd6396/nixos/modules/services/misc/iio-niri.nix)
