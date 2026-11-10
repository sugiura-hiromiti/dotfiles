# Feature / Capability / Provider Contract — Design Specification (Draft)

**Status:** レビュー待ち。原則の提案であり、既存実装の振る舞いを変更したものではない。
**Repository:** `sugiura-hiromiti/dotfiles`
**Evidence baseline:** `main` at `64415b107f055074732d23b8bd4ebe40e54302b8` (2026-11-10 確認)。

## Intent

Feature を **利用者が自由に構成できる公開 API** と **内部で交換・合成できる実装** の接続点にする。Host・Account・Profile が Feature API の値を上書きするのは正当な利用方法であり、Feature は *最終的にマージされた API 値* に従う。内部の Program オプションを利用側に操作させなければ構成できない Feature は抽象化が不十分である。

例: ターミナルを必要とする構成で、既定 WezTerm、Darwin Host の Ghostty、Linux Host の Kitty を Feature の公開 Provider 選択によって表現できるべき。ただし現行 Registry に Ghostty Provider は未実装であり、この例は目標状態。

## Goals / non-goals

- Host / Account / Profile は Feature が公開した設定を Nix module の通常の定義・優先順位で合成・上書きできる。
- Feature は目的・要求・利用可能な能力を記述し、実装は必要に応じて複数の Provider / Program を合成する。
- 選択された能力が契約を満たさない場合は、黙って欠損した構成を生成せず説明可能な評価エラーにする。
- Program・Provider は自らの導入方法・サービス設定・永続化・権限ルールの具体的実装を所有し、Feature は利用可否と組み合わせの意思決定を所有する。
- ただし全ての依存関係に Registry を作らない。実際の交換可能性、複数の利用者、または安定した抽象的役割がある場合に導入する。
- **対象外:** 既存の Nix コード変更、Variant 全廃、全 Feature の一斉移行、共通 Capability Framework の先行実装、秘密情報管理の再設計。

## Chosen approach / alternatives

**採用: 公開契約 + 必要な場所だけ Provider 合成。** Feature API を構成境界とし、選択 Provider の適合性を検証する。共有 Program の存在を排他的に管理するわけではない。

**不採用: Host が Program の内部設定を直接操作する方式。** Host と実装を結合し、API の値だけでは Feature の状態を理解できなくする。

**不採用: Feature が使用する全 Program の enable を排他的に支配する方式。** 共有 Program を使う別 Feature と衝突する。所有するのは *Feature の振る舞い・専有資源・明示した権限* であって、共有依存物の存在全体ではない。

**対象外: 全能力をグローバル Registry に統一する方式。** 名目的な間接参照を増やし、各 Capability の意味を曖昧にする。

## Contract vocabulary

| Concept | Contract |
| --- | --- |
| **Consumer** (Host / Account / Profile / other Feature) | 公開 Feature API に値を提供する。具体 Program の設定詳細に依存しない |
| **Feature** | ある目的を提供する。その機能を実現するための要求、選択、検証を所有する |
| **Capability** | Feature が必要とする能力・操作・保証。パッケージ名と同義ではない |
| **Provider** | Capability を実現する候補。パッケージ、識別子、必要な操作等を契約として公開する |
| **Program** | バイナリ・設定・サービス・永続化・sudoers 等の実装責務を持つ |
| **Target** | HM / NixOS / Darwin は独立評価される。必要な共通意思決定は明示的に渡す |

### Composition and override direction

```text
Host / Account / Profile
        |
        v  (public API; defaults can be overridden)
Feature -- requires --> Capability -- selected via --> Provider(s)
        |                                         |
        +-- validates contract                    v
                                               Program(s)
```

- 公開 API の上書きは正規の使用方法。既定値は Host ごとの差分を封じ込めず、通常の Nix module priority に従う。
- Provider 選択、Package、Capability の設定は必要な範囲で公開する。利用側が `services.*` や `dotfiles.programs.*` の内部状態を直接編集する必要があるなら、Feature API の不足を検討する。
- 構成済み Provider の出力（例: `terminal.selected`）は読み取り専用として公開できる。公開入力と内部の導出値を区別する。
- `lib.mkDefault`、通常の定義、assertion の使い分けは契約に従う。全てを `mkForce` で固定しない。

## Boolean semantics / ownership

`enable = false` の保証対象は **その API が宣言した所有範囲** に限る。全ての Program に一律の「未インストール」を意味させない。

1. **Feature `enable = false`:** その Feature 固有の振る舞い・統合を提供しない。他の利用者が共有 Program を使うことは禁止しない。
2. **Optional dependency `enable = false`:** その Feature からは依存能力を要求しない。他でインストールされた Program を削除しない。
3. **Selected / required capability `enable = true`:** 選択先が契約を満たす必要がある。別定義によって必要な Program が無効化された場合は、実効構成の検証・assertion 等で失敗させるか、代替 Provider を解決する。
4. **Feature が専有する出力・権限 `enable = false`:** 対象の最終状態が無効であることを保証する。競合する直接設定は、黙って通さず評価エラーにする。ただし、Feature に属さない全 system privileges を禁止するものではない。
5. **Shared output:** 所有者と協調のルールを宣言する。単一の Program が複数 Feature から要求されたときに「誰かが必要なら有効」とする場合、その集約は明示的に設計する。暗黙の `enable` の奪い合いを許さない。

例えば `aiTools.nixAgent.privilegedAutomation.enable = false` は、**aiTools が管理する nix-agent 固有の特権自動化**を無効にする。対応する最終 `programs.nix-agent.privilegedAutomation.enable` が true なら設定矛盾として検出する。無関係の sudoers まで網羅的に禁止するという意味ではない。

## Review against current features (not yet migrated)

| Feature | Retain | Gap / next contract |
| --- | --- | --- |
| `terminal` | `provider` と `terminalProviders` / `selected`。Host が provider を選べる | Provider ごとの `mkCommand` の意味（`wait` 等）と提供能力を検証する。Ghostty Provider は現状なし |
| `autoRotation` | Host は `monitor` / `pollingSensorName` のみ公開 API に渡し、Feature が iio-niri と udev を構成 | 有効時に iio-niri が別定義で無効化される競合を契約テストに加える。代替 Provider は必要になるまで導入しない |
| `game` | HM / NixOS で `game.prismlauncher.enable` を公開し、Program と Preservation に実装を任せる | `true` でも Program を別定義で無効化できる。必須構成要素としての `true` の契約を明文化・検証。false は他所の Program 利用まで禁止しない |
| `aiTools` | Codex・Claude Code・Skills 等の既存の個別設定 | nix-agent の導入 / MCP 登録 / 特権自動化を API で構成。権限 false の最終状態を保証し、HM/NixOS の連携を確認 |

## Cross-target semantics

Home Manager と NixOS は同じ Host から派生しても別評価。**同名オプションを両方で定義するだけでは値は同期されない。** 共有したい論理的な選択（例: nix-agent を使うか）は共通 Profile / Target configuration 等の明示的な橋渡しによって同値にする。一方、ユーザー固有・OS 固有の実装詳細は各 Target が所有する。橋渡し方法自体は後続の個別設計で決定する。

## Acceptance criteria for future refactors

1. 異なる Host が公開 API の値を上書きでき、内部実装の編集なしで異なる Provider / Program 構成へ到達する。
2. 選択した Provider が未登録、未対応、または要求 Capability 不足なら、説明的に評価失敗する。
3. Feature が要求する能力の実効値が、競合する Program 設定で壊れたケースをテストする。
4. Feature または optional dependency を無効化しても、共有 Program を使う他の機能を破壊しない。
5. Feature 専有の権限・出力を無効化する場合、管理対象の実効値も無効であり、矛盾を検出する。
6. HM / NixOS で一つの論理的な選択を共有する場合、別々の評価を通じた整合を検証する。
7. 新たな Provider abstraction は具体的な代替実装または複数の Consumer の必要性を説明できる。
8. テストと実機検証を区別し、過去の PASS の記録を今回の実行結果として扱わない。

## Follow-on order (future changes require separate design approval)

1. `terminal`: Provider の契約・互換性テスト（既存 Registry を活用）。
2. `game`: 既存 `true` の不変条件と false の責務範囲を修正。
3. `autoRotation`: 実効状態の assertion と反例テスト。
4. `aiTools`: nix-agent の権限 API、ターゲット間連携、MCP の availability 契約を設計。

**Open for review:** 「Feature 専有」と「共有」の所有者分類は個別の Feature で明示する。全 Program に普遍的な単一所有者を強制する規則とはしない。

## Source references

- [terminal](https://github.com/sugiura-hiromiti/dotfiles/blob/64415b1/nix/modules/home/features/terminal.nix)
- [autoRotation](https://github.com/sugiura-hiromiti/dotfiles/blob/64415b1/nix/modules/nixos/features/auto-rotation.nix)
- [game HM](https://github.com/sugiura-hiromiti/dotfiles/blob/64415b1/nix/modules/home/features/game.nix)
- [game NixOS](https://github.com/sugiura-hiromiti/dotfiles/blob/64415b1/nix/modules/nixos/features/game.nix)
- [aiTools MCP](https://github.com/sugiura-hiromiti/dotfiles/blob/64415b1/nix/modules/home/features/ai-tools/mcp.nix)
