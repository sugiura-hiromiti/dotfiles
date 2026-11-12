# sessionGui Responsibility Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 確定済みの GUI / 復旧用 TTY 契約を維持しながら、sessionGui をセッションと Greeter の Composition に絞る。

**Architecture:** NixOS と Home の sessionGui は `session = "niri"` を明示する。入力方法・X11 互換性・ブート方針は既存の基盤と Runtime / Host Profile に移し、Niri Program は有効な Noctalia Shell にだけ連携する。

**Tech Stack:** NixOS modules, Home Manager, Nix evaluation / derivation checks.

**Spec:** `docs/superpowers/specs/2026-11-12-session-gui-responsibility-design.md`

## Global Constraints

- `feature.enable = false` は原則として Feature 自身の構成寄与を止める意味とする。
- 今回は汎用的なクロスターゲット同期機構を設けない。
- 新しい Feature を無条件に増やさない。
- `runtime.session = "tty"` の用途は **GUI 障害時の復旧** とする。
- GUI は Niri / Noctalia Shell / 日本語入力 / Satellite、および X12 の OSK / 自動回転を維持する。
- Ironbar / OmniWM は既定の設定配布を除き、明示的な Program 利用を維持する。
- no-gui は GUI 世代の自動起動抑制であり、共有 Program を強制無効化しない。
- ロックファイル、認証・遠隔接続 Policy、無関係な Feature は変更しない。

## Review Focus

- Niri の package 上書き時も tuigreet は実効 package の session launcher を使用する（Task 1）。
- Greeter 無効でも外部の greetd / Xwayland 利用は保持する（Task 1）。
- Noctalia Shell の直接有効化と systemd 起動時も IPC が生成され、重複起動しない（Task 2）。
- X12 の SKK 併用は Home custom rule を必要とする（Task 3）。
- TTY は GUI 依存の要求を止めつつ、CLI / NetworkManager / SSH / Tailscale / 認証を保持する（Task 3）。

---

### Task 1: NixOS Session / Greeter Composition

**Files:** `nix/modules/nixos/features/session-gui.nix`, `nix/tests/nixos/session-gui.nix`.

**Interfaces:** 公開 API は `enable`, `session`（enum `niri`、default `niri`）, `greeter.enable`（default true）, `greeter.backend`（noctalia / tuigreet、default noctalia）, `greeter.tuigreet.package` / `user`。ブート方針と Xwayland は構成しない。

- [x] 最小 NixOS 評価テストを先に追加し、未有効時・Greeter 無効・両 backend・package / user 上書き・外部共有 Program 利用・Niri / Greeter の実効無効化・未対応 session の契約を失敗で確認する。
- [x] ロック済み Nixpkgs の Niri session 登録と Greeter の探索を確認し、同じ選択から `niri` desktop entry と実効 package の `niri-session` を生成する。
- [x] 旧 API を廃止し、要求したセッション・Greeter が実効的に成立しない場合を assertion で検出する。AccountsService の要求は Noctalia 上流の所有に委ね、同期認可の primary user を維持する。
- [x] `direnv exec . nix build --no-link --impure --expr '... import ./nix/tests/nixos/session-gui.nix ...'` で assertions を含め成功を確認する。

### Task 2: Home Session Composition / Optional Noctalia Integration

**Files:** `nix/modules/home/features/session-gui.nix`, `nix/modules/home/programs/niri/default.nix`, `nix/modules/home/programs/niri/config/config.kdl`, `nix/tests/home/session-gui.nix`.

**Interfaces:** Home の sessionGui は `enable`, `session`（enum `niri`、default `niri`）のみを提供し、Niri Program を要求する。Program の `noctalia.enable` は実効 `programs.noctalia.enable` に従い、`noctalia.startup.enable` は upstream systemd 起動時 false を既定とする。Task 1 の Greeter に依存しない。

- [x] Home Manager の評価と生成された KDL を対象に、Shell 無効 / Feature 有効 / Program 直接有効 / systemd 起動 / 明示的な連携無効、Niri の独立有効化、Terminal 連携の独立性を先にテストし失敗を確認する。
- [x] Home sessionGui の Program リスト・Fcitx extras・Satellite を除き、Niri の要求と実効状態の assertion に縮小する。
- [x] 固定の Noctalia 起動と IPC キーバインドを条件生成へ移し、有効時の全操作を維持する。Niri Program の任意連携だけで完結する。
- [x] Home 契約 derivation をビルドし、生成物に対する検証を通す。

### Task 3: Runtime / Host Migration and Cross-target Verification

**Files:** `nix/modules/nixos/base/boot.nix`, `nix/modules/nixos/base/input-method.nix`, `nix/profiles/variants/session-gui/{home,nixos}.nix`, `nix/profiles/variants/session-tty/nixos.nix`, `nix/profiles/hosts/x86_64-linux-a/{home,nixos}.nix`, `nix/profiles/systems/x86_64-linux/home.nix`, `nix/tests/system/session-gui.nix`, `nix/checks.nix`, spec implementation record.

**Interfaces:** `dotfiles.nixos.boot.noGuiSpecialisation.enable` は default false、GUI Profile は mkDefault true。specialisation はタグ、multi-user default、tty1 の通常 getty 起動を構成する。Input Method の基盤 default は false、GUI Profile が mkDefault true。Home GUI Profile は libskk と Satellite を要求する。X12 の Hazkey / OSK / rotation は `hasGui` に基づく mkDefault を使用する。

- [x] Runtime / Host テストを先に用意し、TTY の入力方法・OSK・rotation 等の残留と GUI 既定の Ironbar / OmniWM 配布を失敗で確認する。
- [x] 上記所有者へ要求を移し、TTY Profile の defaultUnit を `multi-user.target` とする。古い x86 Home の空 Fcitx extras override を削除する。
- [x] `nix/checks.nix` に NixOS / Home / Host migration checks を登録する。最小モジュールの assertions と実際の Home / NixOS / embedded Home Target の移行表を検証し、独立 Program 有効化も確認する。
- [x] `nix/tests/nixos/recovery-boot.nix` で、Greeter が抑止した autovt に依存せず no-gui が tty1 の通常 getty を起動することを確認する。選択した GUI / 共有 Program は維持する。
- [x] 関連チェック、既存の評価 checks、format / deadnix / statix を実行する。実機や既存の外部ビルド障害による限界は検証済みと分けて記録する。
- [x] spec に新 API・移行記録・成功した検証と未検証事項を記録し、全差分の独立レビューを反映する。

## Execution Notes

- 現在の jj working-copy change は main の子で、仕様書の確定変更が既に存在する。
- sandbox により `.git` への書き込みが禁止され、jj snapshot / commit は不可。作業は現在のディレクトリで行い、開始時の `/tmp/sessiongui-implementation-baseline` とファイル差分で照合する。
- Nix キャッシュは `XDG_CACHE_HOME=/tmp/sessiongui-nix-cache` を使う。flake は未追跡ファイルも含む `path:/home/a/dotfiles` で評価する。
- 各タスクの変更ファイルは分離できるため、NixOS と Home は並行実装し、統合側が Profile と checks を担当する。

### Task 4: Effective Configuration Contract Gaps（2026-11-14）

**Files:** `nix/modules/home/programs/niri/default.nix`, `nix/tests/home/session-gui.nix`, `nix/modules/nixos/features/session-gui.nix`, `nix/tests/nixos/session-gui.nix`、spec 検証記録。

**Interfaces:** 新しい公開 API は追加しない。Niri Program は Home Manager の最終的な `home.file."${config.xdg.configHome}/niri".enable` を検証し、設定配布の無効化を検出する。tuigreet は公開 `user` に対応する既存 NixOS ユーザーを必要とし、アカウント作成は利用側の責務とする。設定 source の上書きや XDG_CONFIG_HOME の変更は許可する。

- [x] Home の Feature / Program 直接利用について、`xdg.configFile.niri.enable = false` と backing `home.file` の強制無効化を負例に追加する。異なる XDG_CONFIG_HOME と source 上書きは正常例にする。
- [x] tuigreet の存在しないカスタムユーザーを負例に追加し、既存のカスタムユーザー正常例を維持する。各回帰テストが修正前に意図した理由で失敗することを確認する。
- [x] Niri Program と NixOS Greeter の所有者に最小の assertion を追加し、Home / NixOS 契約チェックが成功することを確認する。
- [x] 既存4チェックと静的検査、全体の flake 評価を確認し、独立レビューおよび実行範囲を記録する。
