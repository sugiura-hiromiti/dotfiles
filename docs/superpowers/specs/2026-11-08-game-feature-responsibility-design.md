# Game Feature Responsibility Refactor — Design Specification v0.1

**Status:** 実装済み（方針 B：構成要素を明示する Feature API）。評価テスト・対象構成・lint を確認済み。検証結果と実行環境の制約は[実装計画](../plans/2026-11-08-game-feature-responsibility-refactor.md#implementation-results--2026-11-08)を参照。\
**Repository:** `sugiura-hiromiti/dotfiles`\
**Baseline:** GitHub `main` commit `1a7bce2293da159f31c93d8178acf31c427b0e5a`（実装時は最新 HEAD を再確認）。

## Intent

`game` をゲーム環境全体を構成する Feature として定義する。Home Manager によるプログラム導入と NixOS による関連設定を、**同じ意味の Feature API** に従わせ、Program と Preservation の実装責務を保つ。

**One step at a time:** この作業で整理するのは `game` のみ。Variant 全体の廃止、Host/Account/Runtime の再設計、その他の Feature の統合には着手しない。

## Current state

- `nix/modules/home/features/game.nix`: `dotfiles.features.game.enable` と文字列リスト `programs`（default `[ "prismlauncher" ]`）を定義し、有効時に選択された `dotfiles.programs.<name>.enable = lib.mkDefault true` を設定する。
- `nix/profiles/variants/game/home.nix`: `dotfiles.features.game.enable = lib.mkDefault true` を設定する。
- `nix/profiles/variants/game/nixos.nix`: Feature の状態と独立に `dotfiles.programs.prismlauncher.preserveData = lib.mkDefault true` を設定する。
- `nix/modules/home/programs/prismlauncher/default.nix`: PrismLauncher の Home Manager 導入を担当する。
- `nix/modules/nixos/programs/prismlauncher/default.nix`: `preserveData && dotfiles.features.preservation.enable` で `preservation.preserveAt."/persist".users.${accounts.primary}.directories` に `.local/share/PrismLauncher` を追加する。
- `nix/modules/nixos/default.nix`: NixOS Program を import 済みだが、NixOS 用の `game` Feature は未実装。
- X12 と aarch64 Linux の `meta.nix` はいずれも `variants = [ ... "game" ... ]` を宣言している。既存コードの検索では `game.programs` の明示的な利用者は見つからない。ただし実装直前に再検索すること。

## Chosen approach and alternatives

- **採用：構成要素を明示する API（方針 B）。** `dotfiles.features.game.prismlauncher.enable` を Home Manager と NixOS 双方に宣言し、Target 別に具体的な Program オプションへ変換する。未知の文字列名を動的に受け取らず、責務と型が明確になる。
- **不採用：文字列リスト `game.programs` の継続（方針 A）。** Home Manager 側の汎用的な有効化には使えるが、NixOS 側の Program ごとの関係が契約として見えない。
- **今回対象外：Variant 廃止や汎用の cross-target 同期機構。** 各 Target の Nix モジュール評価は独立。既存 Variant を暫定接続点として利用する。

## Public API / Defaults

```nix
# Host または構成 Profile が宣言する意味上の API。
dotfiles.features.game = {
  enable = true;
  prismlauncher.enable = true;
};
```

- `game.enable`: `bool`, default `false`。Feature 全体のオーケストレーションを制御。
- `game.prismlauncher.enable`: `bool`, default `true`。Feature が有効なとき PrismLauncher を構成要素に含めるかを指定。Feature が無効な場合は効果を持たない。
- 旧 `game.programs` (`listOf str`) は削除する。互換エイリアスは設けない（明示的な利用者がないことを再確認）。
- API 名・型・既定値は Home Manager と NixOS で一致させる。新しい共有 Nix 設定ライブラリを作ることは必須ではない。

## Ownership and target-specific behavior

| Owner                         | Responsibility                                                                                                         |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Host / 構成 Profile           | ゲーム環境と構成要素を採用するか決定する                                                                               |
| `game` Feature (HM)           | `game.enable && game.prismlauncher.enable` のとき `dotfiles.programs.prismlauncher.enable = lib.mkDefault true` を要求 |
| `game` Feature (NixOS)        | 同条件で `dotfiles.programs.prismlauncher.preserveData = lib.mkDefault true` を要求                                    |
| PrismLauncher Program (HM)    | PrismLauncher の実際の導入                                                                                             |
| PrismLauncher Program (NixOS) | PrismLauncher データの永続化の具体的実装                                                                               |
| Preservation Feature          | 永続化基盤の提供。有効化判断・機構を `game` に移さない                                                                 |

`lib.mkDefault` を用い、より優先順位の高い独立した Program 設定を上書きしない。`game.enable = false` は Feature 自身の定義を追加しないだけで、他のモジュールの Program 設定を強制的に無効化しない。

| `game.enable` | `game.prismlauncher.enable` | Home Manager からの要求 | NixOS からの要求        |
| ------------- | --------------------------- | ----------------------- | ----------------------- |
| false         | 任意                        | なし                    | なし                    |
| true          | false                       | なし                    | なし                    |
| true          | true                        | Program の有効化        | `preserveData` の有効化 |

`game` が NixOS の永続化を要求しても `preservation.enable = false` なら実際の永続化は発生しない。`game` はその基盤を勝手に有効化しない。`preserveData = false` を Program 側で明示すれば、Feature からの `lib.mkDefault true` に優先する。

## Cross-target and Variant contract

- `nix/profiles/variants/game/home.nix` は従来通り `dotfiles.features.game.enable = lib.mkDefault true` を宣言する。
- `nix/profiles/variants/game/nixos.nix` は `dotfiles.programs.prismlauncher.preserveData` の直接定義を取り除き、`dotfiles.features.game.enable = lib.mkDefault true` を宣言する。
- 両ターゲットでは `prismlauncher.enable` の既定 `true` が使われ、現在の X12 / aarch64 Linux における有効な PrismLauncher 導入と永続化要求を維持する。
- 両 Target に同じ Variant が選択されることで初期値が一致する。ただし、**別々の評価結果を自動同期する仕組みは導入しない**。Target 固有の上書きを行えば両者の有効値が異なる可能性はあり、今回その同期は保証しない。

## Constraints / non-goals

- `game` 内の責務整理に限定する。`preservation` Feature、PrismLauncher Program の既存実装、Host/Account/Runtime、他 Feature の改修は原則行わない。
- 新規ゲームアプリや永続化対象を追加しない。
- `mkForce` による無効化や Program 設定の所有権横取りをしない。
- 既存 Variant の選択システムは維持する。
- `nix/lib/targets.nix` 等の横断的解決ロジックには触れない。

## Acceptance criteria

1. Home Manager: Feature 無効・構成要素無効なら、Feature 起因の PrismLauncher 有効化がない。有効かつ構成要素有効なら、Program が有効になる。
2. NixOS: 同じ条件で `preserveData` への Feature 起因の要求が一致する。
3. `preservation` が無効なら、Feature は永続化基盤を有効化しない。可能であれば実際の `preservation.preserveAt` へのエントリの有無を既存 Program モジュールで確認する。
4. Feature 無効時でも、独立して指定した PrismLauncher の導入・永続化要求は保持される。Feature 有効時でも Program の明示的な `false` は尊重される。
5. `game.programs` は除去され、新 API と両ターゲットでの既定値が一致する。
6. X12 と aarch64 Linux のゲーム環境に関する既存の意図（HM 導入／NixOS 永続化要求）が保持される。
7. Nix の評価テストを追加し、`nix/checks.nix` へ登録する。CI の既存障害があれば変更起因と分けて報告する。

## Evidence / references

- [Home Manager Feature](https://github.com/sugiura-hiromiti/dotfiles/blob/1a7bce2/nix/modules/home/features/game.nix)
- [NixOS PrismLauncher Program](https://github.com/sugiura-hiromiti/dotfiles/blob/1a7bce2/nix/modules/nixos/programs/prismlauncher/default.nix)
- [Variant Home](https://github.com/sugiura-hiromiti/dotfiles/blob/1a7bce2/nix/profiles/variants/game/home.nix)
- [Variant NixOS](https://github.com/sugiura-hiromiti/dotfiles/blob/1a7bce2/nix/profiles/variants/game/nixos.nix)
