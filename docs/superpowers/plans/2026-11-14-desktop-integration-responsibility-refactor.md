# desktopIntegration Responsibility Refactor — Implementation Plan

> **For implementation agents:** 実装前に現行 HEAD / 利用箇所 / ロック済み Nixpkgs・Home Manager の Portal 挙動を確認する。先に契約テストを書き、根本原因ごとに変更・検証する。チェック項目は作業後にのみ完了扱いにする。

**Status:** 実装計画（未実装・未検証）  
**Repository:** `sugiura-hiromiti/dotfiles`  
**Evidence baseline:** `main` commit `1142bfe6f026b0d14186ff1cf2bc90caee75e80c`（2026-11-14）。実装時に最新 HEAD と差分を再確認する。  
**Design contract:** [Feature API と内部 Composition](../specs/2026-11-10-feature-capability-provider-contract-design.md)

## Goal

`desktopIntegration` をデスクトップ統合のオーケストレーターとして残し、利用者が選択した振る舞いを、必要な実装の導入・設定・実効構成まで一貫して提供する。

**最優先の根本問題**は、FileChooser の選択、Backend の提供、ラッパー設定、依存する Terminal / File Manager が独立した条件で構成されていること。これに由来する症状を個別パッチで修正せず、**選択を単一の情報源にする**。

既存コードの分割・行数削減・全設定の Feature 化を目標としない。保証したい振る舞いとその責務の所有者から変更を決める。

## Global Constraints

1. **利用側による構成を優先。** Host / Account / Profile による Public API 上書きを正規の利用方法として扱い、最終的な API 値を Composition に反映する。
2. **Feature は振る舞い、内部は実装。** Host が `xdg.portal.*` や個別の `programs.*` を直接書かずに、公開された選択肢を利用できること。
3. **代替実装が必要なときだけ抽象化。** Portal Provider Registry / Capability Framework / Feature Dependency Resolver を新設しない。
4. **保証と実効構成を一致させる。** 管理対象の Backend を選ぶなら、実際に使える状態まで保証する。構成できないときは妥当な assertion または明確な評価失敗にする。任意の未知 Backend の自動導入を約束しない。
5. **共有資源を排他的に無効化しない。** `desktopIntegration.enable = false` は自身の構成寄与の停止であり、他者の Portal、Keyring、Terminal、Browser、Emacs を禁止するものではない。子オプション `false` / `null` の意味も個別に定義する。
6. **ターゲット間は独立。** NixOS と Home Manager は別々に評価される。同名 API の自動同期を仮定しない。既存 Profile による一貫した既定値と Host による上書きは区別する。
7. **不要な変更を避ける。** `sessionGui`、Terminal Provider の実装本体、Niri、Browser、Yazi、Emacs、他 Feature の再設計に拡大しない。
8. **依存の意味を区別。** 必須依存・既定の自動有効化・任意連携は別概念。共通 `features.*.requires` API は今回追加しない。
9. `mkForce`、具体的 Program の利用、特定実装の設定を、それだけで設計違反としない。保証する契約に必要か・利用側の意図を不当に上書きしないかで判断する。

## Current State / Root Causes

### A. FileChooser Composition が分裂している（中核課題）

- NixOS `desktop-integration.nix` は `portal.fileChooserBackend` と `termfilechooser.enable` を独立させている。`termfilechooser.enable` が false だと FileChooser の選択が設定に反映されない。true なら選択が他 Backend でも termfilechooser を要求する。
- NixOS は `xdg.portal.config.<configName>.FileChooser` に `mkForce` を使用する。上流との競合回避として必要な可能性があるため、理由と優先順位を調査する前に削除しない。
- Home `portal.nix` も `termfilechooser.enable` が true のときだけ FileChooser の設定を追加する。
- Home `termfilechooser.nix` は `terminal.selected` と `config.programs.yazi.package` を参照して wrapper を組み立てる。Terminal が利用不能なケース、別 Backend を選ぶケース、別 Package を利用するケースに対する明示的な契約を持たない。

**一つの原因:** 利用者が要求する FileChooser の選択と、必要な実装の導入・設定・依存の検証が、独立した状態で決まる。

### B. Portal / Secret / Keyring の保証範囲が曖昧

- NixOS Feature は `services.gnome.gnome-keyring.enable = lib.mkDefault true` を Feature 全体の有効化に結びつける。
- Home `portal.nix` は Default / Access / Notification / Secret の Backend 名を設定するが、各 Backend の導入保証がどの層にあるか不明瞭。
- NixOS と Home の `xdg.portal.config` を同時に有効にした際の実際の優先順位・生成物・役割を未確認。

これは A と関連するが、**FileChooser 以外の一般的な Portal / Keyring の提供契約**として独立の判断が必要。無条件に一つの Provider システムへ統合しない。

### C. MIME / Org Protocol の選択とハンドラーの一致が未検証

- Home `mime-apps.nix` の既定では `yazi.desktop` が固定され、Qutebrowser と Glide の分岐は属性集合の `//` 順に依存する（Glide が後勝ち）。
- Home `org-protocol.nix` は `orgProtocol.enable` を最終 `programs.emacs.enable` から既定化し、有効時に assertion を出す。Emacs Package は上書き可能だが、desktop entry / MIME の契約テストがない。

MIME と Org Protocol は FileChooser の選択とは異なる意味上の責務。問題を確認してから独立の変更単位で扱う。

## Proposed Contract (API draft, not an implementation mandate)

`portal.fileChooserBackend` と `termfilechooser.enable` の二つの独立した選択状態を一つに整理する。

```nix
dotfiles.features.desktopIntegration = {
  enable = true;
  portal = {
    enable = true;
    configName = "niri";
    fileChooser.backend = "termfilechooser";
  };
  termfilechooser = {
    package = pkgs.xdg-desktop-portal-termfilechooser;
    fileManager.package = pkgs.yazi;
  };
  mimeApps.enable = true;
  orgProtocol.enable = true;
};
```

- `fileChooser.backend = "termfilechooser"`: 管理対象 termfilechooser の Portal 登録・選択・設定を要求する。
- 他のサポート済み Backend: 実装の提供と Portal 選択を保証できる場合だけサポートする。
- `fileChooser.backend = null`: **この Feature から FileChooser の実装・選択を要求しない**。他者による設定は禁止しない。
- `portal.enable = false`: この Feature の Portal 構成寄与を止める。Portal 専用 wrapper が必要なければ生成しない。他の利用者の Portal は禁止しない。
- `termfilechooser.package` / `fileManager.package`: 選択された実装をカスタマイズする値であり、存在するだけでは termfilechooser の利用要求にならない。
- `desktopIntegration.enable = false`: Feature によるすべての要求・配布を停止する。

**Decision gate:** サポート Backend の選択肢、任意の外部 Backend の扱い、`null` の許可、初期値は、ロック済み依存関係の Backend 識別子と既存 Host の利用意図を確認して確定する。未知の Backend 名を自由に指定することと、その実行可能性まで保証することを混同しない。API の細部より契約の単一情報源化を優先する。

## Task 1: Evidence / Contract Baseline

**Files:** すべての `desktopIntegration` 利用箇所、関連 Feature / Program / Profile、ロックされた Nixpkgs / Home Manager。

- [ ] 最新 HEAD、`jj status` / `git status --short`、関連の未コミット変更を確認し保護する。
- [ ] `rg -n 'desktopIntegration|fileChooserBackend|termfilechooser|xdg\.portal|orgProtocol|mimeApps' nix` で Host / Profile / Feature の参照を網羅する。
- [ ] NixOS・Home Manager が生成する Portal 設定のパス、優先順位、`configName` に対応する desktop 名、`.portal` 記述、`extraPortals` を調べる。
- [ ] 既定 GUI / TTY 各 Target の `xdg.portal`、termfilechooser 設定、Keyring、MIME、Org Protocol の実効値を記録する。
- [ ] termfilechooser wrapper の CLI・依存 Package・Terminal コマンドの待機動作・Yazi 利用方法を調べる。
- [ ] `gnome-keyring` の要求が Secret Portal の必須要件か、GUI 全体の Policy か、他機能の共有要求かを調べる。
- [ ] 管理する Backend と、既存の外部提供 Backend の境界を決定する。

**Acceptance:** どの Target が何を提供するか、何が今回の保証範囲かを明文化できる。調査結果なしに API を固定しない。

## Task 2: FileChooser Single-Source Composition

**Files:**
- `nix/modules/nixos/features/desktop-integration.nix`
- `nix/modules/home/features/desktop-integration/portal.nix`
- `nix/modules/home/features/desktop-integration/termfilechooser.nix`

- [ ] 最小 NixOS / Home Manager 評価テストを先に追加し、現在の二重状態で生じる契約違反を確認する。
- [ ] Public API の Backend 選択を単一の意味上の値にまとめ、旧 `portal.fileChooserBackend` / `termfilechooser.enable` の参照を移行する。
- [ ] 管理対象 Backend の選択から、必要な `extraPortals`、FileChooser Portal 設定、wrapper 設定を導出する。
- [ ] Backend が `null` や他の実装なら、不要な termfilechooser / Terminal / File Manager の実装詳細を評価しない。
- [ ] Portal の選択と最終的な設定・実装提供が合っていなければ、説明的な契約エラーにする。
- [ ] 上流との Portal 設定優先順位を調べてから `mkForce` の要否を判断する。必要なら使用理由と保証範囲を記録する。

**Acceptance:** Backend の選択・導入・設定・無効化が一つの契約から導出され、複数の独立した「選択フラグ」を持たない。

## Task 3: Terminal / File Manager Dependency and Package Overrides

**Files:** Home `termfilechooser.nix` と契約テスト。Terminal / Yazi の他モジュールは原則変更しない。

- [ ] termfilechooser 選択時にだけ、Terminal Provider が利用可能であることを確認する。
- [ ] Terminal Feature が無効でも無関係の Backend が評価でき、`terminal.selected` 属性欠落のような意図しない評価エラーを生まないことをテストする。
- [ ] Terminal Provider を Host から変更した場合、実効 Provider の `mkCommand { wait = true; }` と Package が wrapper に反映される。
- [ ] `fileManager.package` を上書きした場合、wrapper の実効 PATH / 起動処理に反映される。
- [ ] File Manager Program 自体の `enable` が wrapper の成立に必要かは、単純に仮定せず上流 wrapper と Package の内容から確認する。
- [ ] Terminal を自動有効化するかは、必須依存・既定有効化の意味を区別して判断する。**既定案:** Terminal の選択は Terminal Feature に任せ、欠落時は説明的な assertion とする。

**Acceptance:** 必要な実装だけを要求し、Host の Provider / Package 上書きを尊重する。

## Task 4: Shared Portal, Secret / Keyring Ownership

**Files:** NixOS `desktop-integration.nix`、Home `portal.nix`、必要な契約テスト。

- [ ] Portal の有効化が `lib.mkDefault true` で他の利用者と安全に Composition されることを確認する。
- [ ] `xdg.portal.config` の最終値が API 選択と矛盾した場合の診断を設計する。
- [ ] NixOS と Home Manager の Portal 設定を両方入れたときの具体的な生成物を検証する。
- [ ] Secret Backend の選択と `services.gnome.gnome-keyring.enable` の関係を確認し、必要なら適切な所有者へ要求を移す。
- [ ] Feature / `portal.enable` の無効化が共有 Portal・Keyring を強制無効化しないことを検証する。
- [ ] Keyring を別 Feature へ分離するのは、独立した利用契約が本当に必要な場合に限る。

**Acceptance:** Portal / Keyring の有効化・無効化・共有の意味が説明可能で、実効構成に一致する。

## Task 5: MIME / Org Protocol (separate change unit)

**Files:**
- `nix/modules/home/features/desktop-integration/mime-apps.nix`
- `nix/modules/home/features/desktop-integration/org-protocol.nix`

- [ ] Qutebrowser / Glide の後勝ち順、`yazi.desktop` 固定、`emacsclient.desktop` 既定化の意味を Profile / Host の利用方針に照らして確認する。
- [ ] `mimeApps.defaultApplications` への Host の明示指定が優先されることを検証する。
- [ ] 自動既定値が無効なハンドラーを指す場合の保証範囲を定義する。実装 Package・desktop entry の存在を検証するか、単なる既定選択と明記するか決める。
- [ ] `orgProtocol.enable` の有効・無効、Emacs の実効有効状態、`emacsPackage` 上書き、`org-protocol.desktop` と MIME 関連付けを検証する。
- [ ] 独立 Emacs / Browser / Yazi の設定を他 Feature の無効化で消さない。
- [ ] Browser Registry や汎用 MIME Provider Framework を導入しない。

**Acceptance:** ハンドラーの選択と登録が明示的な Policy / 契約で説明できる。A の解消に直接必要な変更でなければ独立タスクに分離する。

## Task 6: Profile / Host Migration and Tests

**Likely files:**
- `nix/profiles/variants/desktop-integration/home.nix`
- `nix/profiles/variants/desktop-integration/nixos.nix`
- `nix/tests/home/desktop-integration.nix` (new)
- `nix/tests/nixos/desktop-integration.nix` (new)
- `nix/tests/system/desktop-integration.nix` (as needed)
- `nix/checks.nix`

- [ ] 最新の旧 API 利用箇所をすべて移行し、未対応オプションを黙って無視しない。
- [ ] NixOS / Home Manager を**独立に**評価する最小テストを用意する。
- [ ] X12 native と aarch64 Linux Parallels / QEMU の GUI・TTY / Theme から必要な Target を確認する。
- [ ] Embedded Home Manager と standalone Home Manager の構成差分を確認する。
- [ ] 正常ケースと意図した失敗を評価し、Nix の遅延評価で assertions が飛ばされないようにする。
- [ ] 生成される `portals.conf`、termfilechooser の設定と wrapper の参照をできる範囲で検証する。
- [ ] `nix/checks.nix` に専用 checks を登録し、成功したものと実行できなかったものを区別する。
- [ ] 変更した Nix の format、既存チェック、代表 Host の評価・ビルドを行う。無関係の外部要因による失敗を切り分ける。

### Required Contract Matrix

| ケース | Expected |
| --- | --- |
| `desktopIntegration.enable = false` | Feature 自身の設定寄与なし |
| 外部 Portal / Keyring が別途有効 | Feature 無効でも保持 |
| `portal.enable = false` | Feature 起因の Portal / wrapper 設定を要求しない |
| `fileChooser.backend = "termfilechooser"` | 管理対象実装・登録・設定が整合 |
| `fileChooser.backend = null` | FileChooser Backend の選択を要求しない |
| 別のサポート済み Backend | 不要な Terminal / termfilechooser を要求しない |
| Terminal が必要なのに未提供 | 意図した契約エラー。属性欠落エラーではない |
| Terminal Provider 上書き | 実効 Package / コマンドへ追従 |
| File Manager Package 上書き | wrapper に反映 |
| Portal configName 上書き | 対象デスクトップの設定へ反映 |
| 最終 Portal Backend が意図と不一致 | 契約エラー、または明確に記述した競合診断 |
| MIME / Org Protocol 有効・無効 | 必要な desktop entry / MIME 設定のみ生成 |
| Emacs なしの Org Protocol 要求 | 明確な契約エラー |
| GUI / TTY Host | 各 Runtime の利用方針に一致 |

## Execution Order

1. **Baseline を記録**: 未コミット変更、利用箇所、ロックされた Portal 実装の調査。
2. **最小契約テストを追加**: FileChooser の破綻ケースを先に再現。
3. **FileChooser の単一情報源化**: Backend 選択から構成を導く。
4. **Terminal / File Manager の実装連携を修正**: 依存欠落と上書きを検証。
5. **共有 Portal / Keyring を整理**: 別責務として判定。
6. **MIME / Org Protocol を整理**: 独立の変更単位として扱う。
7. **Host 移行と検証**: 最終構成、既存 checks、差分をレビュー。

各 Task を小さなレビュー可能なコミットに分ける。Task 5 が不要な変更になる場合は完了扱いにせず、根拠を報告して見送る。

## Non-goals

- すべての Portal Backend を汎用的にサポートすること。
- Portal Provider Registry / Capability Framework / Feature Dependency Resolver の新設。
- Terminal、Niri、Yazi、Glide、Emacs の本体再設計。
- 全 Host の構成を無条件に同一化すること。
- Home Manager と NixOS の汎用同期機構。
- 単に `mkForce` を除去すること、具体的 Program への直接依存を禁止すること。
- リファクタリングと無関係の設定・パッケージ更新。

## Definition of Done

- [ ] `desktopIntegration` の責務境界と保証範囲が明文化されている。
- [ ] FileChooser の実装選択が単一の情報源になり、管理対象 Backend が実際に提供される。
- [ ] Terminal / File Manager の依存と Package 上書きが実効構成に反映される。
- [ ] 不要な Backend が不要な実装依存を評価しない。
- [ ] Feature および Portal 子オプションの無効化が他者の共有 Program を禁止しない。
- [ ] Host が公開 API を通じて希望する選択と上書きを表現できる。
- [ ] Portal、Keyring、MIME、Org Protocol の責務と制約が説明され、必要なチェックがある。
- [ ] NixOS と Home Manager の独立性を考慮した Profile / Host の期待値が検証された。
- [ ] 成功した Nix checks、未実行・失敗チェック、実機未検証事項を明示している。
- [ ] 不要な汎用抽象化を追加していない。

## Implementation Report Format

実装後、(1) 根本原因と症状、(2) Public API と互換性・移行、(3) 各 Backend / Portal / Keyring の所有権、(4) 実効構成と契約テスト、(5) 変更ファイル、(6) 実行した checks・失敗要因、(7) 意図した振る舞い変更・未解決事項を報告する。

> 最終判断基準は「Feature が利用者に約束する振る舞いを、選択された実装の実効構成が満たしているか」。内部実装の都合や既存ファイルの境界を優先しない。
