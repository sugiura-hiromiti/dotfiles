# sessionGui Responsibility Refactor — Design & Implementation Handoff

**Status:** 実装 AI 向け設計仕様（未実装・未検証）  
**Repository:** `sugiura-hiromiti/dotfiles`  
**Evidence baseline:** `main` commit `85e9ebd6227b2278c3b530e691613af5bdce3496`（2026-11-12）  
**Scope:** NixOS / Home Manager の `sessionGui` と、その責務分離に直接必要な周辺構成

> 実装開始時には必ず最新 HEAD、関連モジュール、Host/Profile、flake.lock、git/jj の未コミット変更を確認すること。この文書は既存実装の構造・デフォルト値・テスト期待値を正解として保証しない。

## 1. Intent と判断基準

**`sessionGui` はグラフィカルセッションのオーケストレーターとして維持する。**

公開契約は「選択されたグラフィカルセッションを提供し、選択されたログイン手段がそのセッションを正しく起動できるように構成する」こととする。

[Feature API と内部 Composition の設計原則](2026-11-10-feature-capability-provider-contract-design.md) を優先する。

- Host / Account / Profile が公開 API を通常の Nix module 優先順位で構成・上書きできること。
- Host が `programs.*` / `services.*` の実装詳細を直接操作しなくても、Feature の公開された選択肢を利用できること。
- 共有 Program の排他的な単一所有者を仮定しないこと。`feature.enable = false` は原則として Feature 自身の構成寄与を止める意味とする。
- Feature の約束と実効構成が不一致なら、必要な場所で assertion 等により検出すること。自動フォールバックは必須としない。
- 実際の交換可能性が必要になるまでは、共通 Provider Framework、Capability Registry、抽象化のための抽象化を新設しないこと。
- 一つの根本原因が生む複数の症状を別々の独立した問題として修正しないこと。

## 2. 現状の根本的な問題

### 2.1 Session と Greeter が一つの契約から構成されていない

現行 `nix/modules/nixos/features/session-gui.nix` では次の3つが独立している。

1. `sessionGui.niri.enable` により `programs.niri.enable` を構成する。
2. `sessionGui.greeter.sessionCommand` は `tuigreet` 起動時にだけ使われる。
3. Noctalia Greeter の `settings.session.default` は `"niri"` に固定されている。

`greeter.sessionCommand` が Noctalia に反映されないこと、Niri を無効にしても Noctalia が Niri を要求することは、**「セッション選択の情報源が分裂している」という同一の根本原因**の症状である。局所的な option や条件分岐の追加だけで対処しない。

### 2.2 セッション成立と周辺 GUI 機能の混同

現行 `nix/modules/home/features/session-gui.nix` の `programs` は文字列リストとして `fcitx5`、`ironbar`、`libskk`、`niri`、`omniwm` を有効化し、`xwayland-satellite` を無条件に Home Package へ追加する。

これらは同一の責務ではない。Compositor のセッション構成、入力方法、Panel、独立した Window Manager、X11 互換性を同一 Feature が包括的に所有する必要性を再評価する。

### 2.3 システム運用・基盤サービスの混入

NixOS 側は `services.accounts-daemon.enable = true` を無条件に構成し、`no-gui` specialisation を作成する。また `programs.xwayland.enable = cfg.xwayland.enable` は `false` の場合にも明示的な無効化定義を追加する。

共有基盤やブート運用方針をセッション Feature が排他的に所有すべきか、オプションごとの `false` が何を保証するかを見直すこと。

## 3. Target public API（暫定）

`sessionGui` の公開 API は、利用者が必要な振る舞いを選択する最小構造から始める。

```nix
dotfiles.features.sessionGui = {
  enable = true;
  session = "niri";
  greeter = {
    enable = true;
    backend = "noctalia";
  };
};
```

| Option | 初期値案 | 契約 |
| --- | --- | --- |
| `enable` | `false` | Feature 自身によるグラフィカルセッション構成を有効化 |
| `session` | `"niri"` | 提供するグラフィカルセッションを選択 |
| `greeter.enable` | `true` | ログイン画面をこの Feature から要求するか |
| `greeter.backend` | `"noctalia"` | 利用する Greeter 実装（現状は Noctalia / tuigreet） |

これらの既定値は実装時に検証する**暫定案**であり、単に現在と同じ値だから採用するわけではない。最初の実装では `session` の選択肢を `"niri"` に限定してよい。未対応値は明確な評価エラーにする。

Greeter 固有のカスタマイズが必要なら実装名の下に分離する。

```nix
dotfiles.features.sessionGui.greeter = {
  backend = "tuigreet";
  tuigreet = {
    package = pkgs.tuigreet;
    user = "greeter";
  };
};
```

上記は API 形状の例。利用者が必要とする値だけを公開し、上流 NixOS option をすべて複製しないこと。Greeter 共通の `sessionCommand` といった、実際には片方にしか適用できない疑似共通 API は設けない。

## 4. Session → Greeter Composition

選択したセッションについて、内部で少なくとも以下の意味上の情報を扱う。

- セッション実装を有効化するために必要な構成
- tuigreet が用いる起動コマンド
- Noctalia が認識するセッションエントリの識別子

実装スケッチ（NixOS module の完成コードではない）：

```nix
sessions = {
  niri = {
    desktopName = "niri";
    command = lib.getExe' pkgs.niri "niri-session";
  };
};

selectedSession = sessions.cfg.session;
```

※ 上記 `desktopName` と起動コマンドは**事前確認が必要な例**。ロック済み Nixpkgs、Niri、Noctalia Greeter の実際のセッション登録・探索方法を確認し、正確な値を使用すること。

- Noctalia と tuigreet は **同一の選択されたセッション** から各自に必要な値を取得する。
- `session = "niri"` なら Niri セッションの提供を要求し、最終的に起動可能であることを検証する。
- 別モジュールが意図的に実装を無効化して契約を満たせない場合、黙って壊れた構成を出さず、説明的な assertion で検出する。
- `greeter.enable = false` はこの Feature がログイン画面を要求しないことを意味し、セッション自体の提供は継続する。
- Greeter を無効にしたことで、別モジュールが有効にした Greeter を強制無効化してはならない。
- 将来の交換可能性を見据えつつ、当面は Niri への直接的な Composition で十分。共通 Provider Framework を新設しない。

## 5. 責務の再配置

| 現状の対象 | 目標の所有者 / 扱い | 判断基準 |
| --- | --- | --- |
| Niri のシステム側導入 | `sessionGui` の Session Composition | 選択セッションの成立に必須 |
| Greeter 選択・構成 | `sessionGui` | 中核的なオーケストレーション |
| Niri の Home Manager 設定 | Home 側の Session Composition と既存 Niri Program | 実装固有設定を再利用 |
| Fcitx5、libskk | Input Method / SKK 側 | セッション成立から独立して選択できる |
| Ironbar | Panel の適切な Feature または Profile | セッション成立に必須ではない |
| OmniWM | 独立した Program / Profile | セッション成立に必須ではない |
| Xwayland、Xwayland Satellite | X11 互換機構を選択する責務 | 実装ごとの役割を調べてから決定 |
| AccountsService | 実際に必要とするサービス / Feature | 無条件のセッション依存としない |
| no-gui specialisation | ブート・運用 Policy（例：`dotfiles.nixos.boot.*`） | セッションそのものではない |

**新しい Feature を無条件に増やさない。** 既存 Program / Profile で適切に構成できるなら、それを利用する。移行先の判断では、現在の既定 Program 群をそのまま保存することを目的にしない。ただし、利用者が意図している機能を偶然消さないよう、Host ごとの結果を検証する。

### Home Manager と NixOS の独立性

両 Target は独立して Nix module を評価するため、同名 `dotfiles.features.sessionGui.session` を宣言するだけでは同期されない。

まず NixOS 側でセッションと Greeter の契約を成立させ、Home Manager 側は必要なユーザー設定の Composition のみに縮小する。共通 Profile など既存の Profile Resolution を使用する場合も、独立した上書きによって値が変わる可能性を明記し、検証すること。

今回は汎用的なクロスターゲット同期機構を設けない。

### no-gui と TTY は別概念

- `runtime.session = "tty"` は生成する Target のコンテキスト。
- `no-gui` specialisation は同じ NixOS 世代から GUI 自動起動なしで起動する手段。

`no-gui` の目的は原則として GUI ログインの自動起動抑制であり、すべての GUI Package を削除する保証ではない。specialisation のブート動作を意図的に強制変更する `mkForce` と、共有 Program を無効化する `mkForce` を混同しない。

### AccountsService と権限

Noctalia / AccountsService の実際の要求元と副作用を確認する。`passwordlessSyncUsers` のような認可に関わる設定は、単なる表示オプションとして移動せず、権限の意味と保証範囲を調べ、意図しない拡大・縮小を禁止する。

### X11 互換性

`programs.xwayland` と `xwayland-satellite` は単に同じフラグで操作できるものと仮定せず、選択した Compositor と実際の役割を確認する。Feature が利用しない状態を示す `false` と、共有サービスの明示的な停止命令は区別する。

## 6. 廃止・移行を検討する旧 API

以下を全リポジトリで検索し、利用箇所を移行する。

- NixOS: `sessionGui.niri.enable`
- NixOS: `sessionGui.greeter.sessionCommand`、`greeter.package`、`greeter.user`
- NixOS: `sessionGui.xwayland.enable`、`sessionGui.noGuiSpecialisation.enable`
- Home: `sessionGui.programs`、`sessionGui.fcitx5.packages`、`sessionGui.xwaylandSatellite.package`

旧 API を残すか廃止するかは、ユーザー向けの実際の契約と利用箇所を調査して判断する。未対応の設定を黙って無視しないこと。必要なら互換性対応を明示する。

## 7. 実装順序

1. **Baseline / Evidence**
   - 最新 HEAD、未コミット変更、関連 option の参照箇所を再確認する。
   - ロック済み Nixpkgs と Noctalia の実装からセッション登録と起動方式を確認する。
   - `sessionGui` による現在の実効構成と各 Host の意図した利用機能を区別して記録する。

2. **Contract tests**
   - 新しい `sessionGui` 公開 API の値、無効化の意味、選択の整合性を最小評価テストで定義する。
   - 旧実装の出力をそのまま正として期待値にしない。

3. **Session Composition**
   - 単一の `session` から Compositor / Greeter 設定を生成する。
   - Greeter ごとの起動契約を分離し、セッション選択の不一致をなくす。
   - 明示的な競合を assertion で検出する。

4. **Responsibility extraction**
   - Home の文字列 Program リストを解体し、独立した機能を適切な Feature / Program / Profile に移す。
   - X11 互換性、AccountsService、no-gui specialisation の責務を分離する。
   - 必要以上に広い横断 refactor に着手しない。

5. **Host / Profile migration**
   - GUI / TTY の Runtime Profile、ThinkPad X12 と aarch64 Linux Host、Home / NixOS の構成を点検する。
   - 必要な機能は適切な所有者から再び要求する。現在の `sessionGui.programs` が示す Program 全部を無条件に有効にする必要はない。

6. **Verification / Reporting**
   - 最小評価、既存 checks、主要 Host ターゲット評価を実施する。
   - 実機でしか確認できない点は未検証として残し、成功を推測しない。
   - 意図的な動作変更、維持した動作、残存する制約を報告する。

## 8. 必須の契約テスト

`nix/tests/nixos/session-gui.nix` と `nix/tests/home/session-gui.nix` 等を検討し、必要な tests を `nix/checks.nix` に登録する。

- Feature 未有効では、Feature 起因の設定寄与がない。
- Feature 無効でも、他の利用者が同じ Program / Service を有効にできる。
- `session = "niri"` が選ばれれば、Niri セッションが提供される。
- Noctalia は選択されたセッションエントリを参照する。
- tuigreet は選択されたセッションの正しい起動コマンドを使う。
- Greeter を無効にしてもセッション構成が成立する。
- セッション提供が実効的に阻害されたとき、明確な不整合を検出できる。
- 利用側からの公開 API 上書きが実効構成に反映される。
- Fcitx5 / libskk / Panel / OmniWM の有無はセッション成立の暗黙の必須条件にならない。
- X11 互換性を要求しない場合、他の利用者の Xwayland 利用を妨げない。
- GUI / TTY の Target で、それぞれ定義した契約が成立する。
- no-gui specialisation はその定義されたブート契約を満たす。
- 認可に関する変更は意図された場合だけ発生する。

NixOS や Home Manager が出す assertions は Nix の遅延評価で飛ばされないよう、テスト側で実際に評価すること。

## 9. Feature 間依存宣言の将来構想（今回非スコープ）

将来、Feature 同士の依存関係を宣言的に記述する仕組みが必要になる可能性がある。

例（**未採用の構想**）：

```nix
dotfiles.features.someFeature.requires = [
  "someFeature1"
  "someFeature2"
];
```

ただし今回の `sessionGui` refactor に導入しない。今は次の原則だけを保持する。

1. Feature 間の必須依存を暗黙にしない。
2. 必須依存・自動有効化・任意連携を区別する。
3. 複数の具体例で必要性が確認できた時点で共通 API を検討する。

特に、Feature 自体の成立に必須な依存を、利用者が自由に `requires = []` と消せる公開 API として置くことは避ける。内部契約とユーザー選択を区別すること。

## 10. Non-goals

- すべての Program の Feature 化、Feature 数の最大化。
- 汎用 Provider / Capability / Dependency Framework。
- クロスターゲット設定の汎用同期。
- 複数 Compositor の新規サポート。
- Variant / Runtime / Host モデル全体の再設計。
- 現状のすべてのデフォルトやテスト期待値の無条件保存。
- 今回の責務分離に関係しない設定の整理。

## 11. Definition of Done

- [ ] `sessionGui` の責務が「セッションの提供とログイン手段の整合性」に集約される。
- [ ] Host 等が公開 API のみでセッションと Greeter を構成できる。
- [ ] Niri / Noctalia / tuigreet の間でセッション選択の情報源が一つになる。
- [ ] Feature の約束と実効構成が一致し、不一致時は明確に失敗する。
- [ ] 入力方法、Panel、OSK、OmniWM はセッション成立に無条件で束縛されない。
- [ ] X11 互換性、AccountsService、no-gui specialisation の責務が整理される。
- [ ] 共有 Program の非排他的利用が維持される。
- [ ] NixOS / Home Manager の独立性を踏まえた Host / Runtime 移行が完了する。
- [ ] 追加した評価テストおよび可能な環境でのビルドが検証される。
- [ ] 変更理由、意図的な動作差分、未検証事項が記録される。
- [ ] 今回不要な汎用抽象化を導入していない。

## 12. 実装 AI の報告形式

1. 発見した**根本原因**と、それに由来する症状。
2. 採用した責務境界と、代替案を選ばなかった理由。
3. 変更した Public API と利用側の移行方法。
4. 内部 Composition の構造と実効構成の検証方法。
5. 変更ファイル・動作差分・権限への影響。
6. 実行した Nix 評価・checks・ビルドの成否。
7. 未解決の事項と、今回の範囲外として残した課題。

**最終判断基準：**「その責務は Feature が公開する振る舞いの一部か、内部実装の詳細か、それとも独立した機能か」。既存ファイル配置や行数削減ではなく、この判断から変更を導くこと。
