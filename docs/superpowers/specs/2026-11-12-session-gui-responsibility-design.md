# sessionGui Responsibility Refactor — Design & Implementation Handoff

**Status:** 実装済み・契約テスト通過（実機未反映、実装記録は第13節）\
**Repository:** `sugiura-hiromiti/dotfiles`\
**Evidence baseline:** `main` commit `85e9ebd6227b2278c3b530e691613af5bdce3496`（2026-11-12）\
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

| Option            | 初期値案     | 契約                                                 |
| ----------------- | ------------ | ---------------------------------------------------- |
| `enable`          | `false`      | Feature 自身によるグラフィカルセッション構成を有効化 |
| `session`         | `"niri"`     | 提供するグラフィカルセッションを選択                 |
| `greeter.enable`  | `true`       | ログイン画面をこの Feature から要求するか            |
| `greeter.backend` | `"noctalia"` | 利用する Greeter 実装（現状は Noctalia / tuigreet）  |

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

selectedSession = sessions.${cfg.session};
```

※ 上記 `desktopName` と起動コマンドは**事前確認が必要な例**。ロック済み Nixpkgs、Niri、Noctalia Greeter の実際のセッション登録・探索方法を確認し、正確な値を使用すること。

- Noctalia と tuigreet は **同一の選択されたセッション** から各自に必要な値を取得する。
- `session = "niri"` なら Niri セッションの提供を要求し、最終的に起動可能であることを検証する。
- 別モジュールが意図的に実装を無効化して契約を満たせない場合、黙って壊れた構成を出さず、説明的な assertion で検出する。
- `greeter.enable = false` はこの Feature がログイン画面を要求しないことを意味し、セッション自体の提供は継続する。
- Greeter を無効にしたことで、別モジュールが有効にした Greeter を強制無効化してはならない。
- 将来の交換可能性を見据えつつ、当面は Niri への直接的な Composition で十分。共通 Provider Framework を新設しない。

## 5. 責務の再配置

| 現状の対象                                    | 目標の所有者 / 扱い                                | 判断基準                             |
| --------------------------------------------- | -------------------------------------------------- | ------------------------------------ |
| Niri のシステム側導入                         | `sessionGui` の Session Composition                | 選択セッションの成立に必須           |
| Greeter 選択・構成                            | `sessionGui`                                       | 中核的なオーケストレーション         |
| Niri の Home Manager 設定                     | Home 側の Session Composition と既存 Niri Program  | 実装固有設定を再利用                 |
| Fcitx5、libskk                                | Input Method / SKK 側                              | セッション成立から独立して選択できる |
| Ironbar、Noctalia Shell                       | それぞれの Program / Feature と利用側の Profile    | セッション成立に必須ではない         |
| Niri からの Noctalia Shell 起動・キーバインド | Niri Program の任意連携設定                        | 有効な実装に対してだけ生成する       |
| OmniWM                                        | 独立した Program / Profile                         | セッション成立に必須ではない         |
| Xwayland、Xwayland Satellite                  | X11 互換機構を選択する責務                         | 実装ごとの役割を調べてから決定       |
| AccountsService                               | 実際に必要とするサービス / Feature                 | 無条件のセッション依存としない       |
| no-gui specialisation                         | ブート・運用 Policy（例：`dotfiles.nixos.boot.*`） | セッションそのものではない           |

**新しい Feature を無条件に増やさない。** 既存 Program / Profile で適切に構成できるなら、それを利用する。移行先の判断では、現在の既定 Program 群をそのまま保存することを目的にしない。ただし、利用者が意図している機能を偶然消さないよう、Host ごとの結果を検証する。

### Niri と Noctalia Shell の任意連携

現行 `nix/modules/home/programs/niri/config/config.kdl` には、Noctalia Shell の `spawn-at-startup` と、Launcher / Clipboard / Session / 通知 / 音量 / マイク音量 / 明るさを操作する Noctalia IPC のキーバインドが固定で含まれている。Program の有効化だけを分離しても、この依存は残る。

- Noctalia 固有の起動・キーバインドの生成責務は Niri Program に置き、任意連携として条件付きで生成する。`sessionGui` はこの連携のために Noctalia Shell を必須化しない。
- 生成条件は Home Manager の最終的な Niri 設定と Noctalia Shell 実装の有効状態に基づく。`noctaliaShell.enable` だけで判定せず、他の利用者が有効化した共有 Program も扱えること。
- Noctalia Shell が無効なら、それを起動・操作する行を生成しない。Niri 自体と、Terminal 等の独立した連携は引き続き構成できること。
- Noctalia Shell が有効な既存 GUI 構成では、意図された起動と各操作を維持する。他の起動経路がある場合は重複起動を避ける。
- Noctalia **Greeter** の選択と、ログイン後の Noctalia **Shell** の連携条件は独立させる。Greeter が Noctalia でも Shell を必須にせず、tuigreet でも Shell を利用できること。
- Shell 無効時に別の Panel や操作コマンドへ自動で置換することは要求しない。今回不要な共通 Panel Provider API は新設しない。

### Home Manager と NixOS の独立性

両 Target は独立して Nix module を評価するため、同名 `dotfiles.features.sessionGui.session` を宣言するだけでは同期されない。

まず NixOS 側でセッションと Greeter の契約を成立させ、Home Manager 側は必要なユーザー設定の Composition のみに縮小する。共通 Profile など既存の Profile Resolution を使用する場合も、独立した上書きによって値が変わる可能性を明記し、検証すること。

今回は汎用的なクロスターゲット同期機構を設けない。

### no-gui と TTY は別概念

- `runtime.session = "tty"` は生成する Target のコンテキスト。
- `no-gui` specialisation は同じ NixOS 世代から GUI 自動起動なしで起動する手段。

`no-gui` の目的は原則として GUI ログインの自動起動抑制であり、すべての GUI Package を削除する保証ではない。specialisation のブート動作を意図的に強制変更する `mkForce` と、共有 Program を無効化する `mkForce` を混同しない。

### TTY Target の用途と契約（確定）

`runtime.session = "tty"` の用途は **GUI 障害時の復旧** とする。対象は ThinkPad X12（`x86_64-linux-a`）と `aarch64-linux-a` の Home / NixOS Target。GUI セッションを起動せずにログインし、設定修正・再ビルド・ロールバック等の復旧操作を行える構成にする。

- 既定の NixOS ブート先は `multi-user.target` とし、GUI セッション・ログイン画面の自動起動を要求しない。Home 側も Niri 設定・Panel・その起動連携を要求しない。
- GUI 用の入力方法（Fcitx5 / Hazkey と各 addon・設定）、X11 互換機構、OSK、自動回転を、この復旧用 Runtime の Profile / Host Policy から要求しない。TTY コンソールのキーボード・ロケール設定は維持する。
- 既存の CLI 基盤、Nix の更新・ロールバック経路、ユーザー / 認証、NetworkManager、SSH / Tailscale は維持する。GUI を無効にするために遠隔復旧経路や認証ポリシーを変更しない。
- 各 Feature / Program の選択は通常の module 優先順位で構成する。移行対象を TTY から要求しないことと、他の利用者による共有 Program の明示的な有効化を `mkForce false` で禁止することを区別する。
- この refactor に無関係な Feature や Package を一括削除しない。復旧用 TTY の契約は、全 GUI Package が依存閉包から消えることではなく、復旧操作が GUI の起動に依存しないことである。

現状は `sessionGui` を無効にするだけではこの契約にならない。NixOS の `dotfiles.nixos.inputMethod.enable` は既定で有効であり、X12 Host は Hazkey / OSK / 自動回転を Runtime に関係なく要求している。特に Hazkey の上流 user service は `default.target` に登録される。これらの要求を GUI / TTY の利用 Policy に従って分離すること。調査時点のソース上の条件と、移行後の実効構成の検証結果は区別して報告する。

`no-gui` specialisation は引き続き GUI 構成を持つ同じ世代からの自動起動抑制手段とし、この復旧用 TTY Target と同じ構成への置換は行わない。

### Host / Runtime ごとの既定構成（確定）

以下は利用者と確認した**移行後の期待値**であり、現在の実装を評価した結果ではない。Feature 単体の暫定デフォルトとは分けて、Host / Profile の利用 Policy として構成する。`要求なし` は当該 Policy から有効化・設定配布を要求しない意味であり、共有 Program の明示的な利用や間接依存 Package の存在を禁止する意味ではない。両 Host の Home / NixOS Target に適用し、Theme や Deployment によって意図せず差が生じないことを検証する。

| 機能 / 対象 Target                                | X12 GUI                               | aarch64 Linux GUI             | 両 Host の復旧用 TTY | 要求元の責務                                             |
| ------------------------------------------------- | ------------------------------------- | ----------------------------- | -------------------- | -------------------------------------------------------- |
| Niri システム導入 / NixOS                         | 要求する                              | 要求する                      | 要求なし             | GUI Profile → Session Composition                        |
| Niri ユーザー設定 / Home                          | 要求する                              | 要求する                      | 要求なし             | GUI Profile → Home Session Composition → Niri Program    |
| Greeter / NixOS                                   | Noctalia                              | Noctalia                      | 要求なし             | GUI Profile → `sessionGui.greeter`                       |
| Noctalia Shell / Home                             | 要求する                              | 要求する                      | 要求なし             | GUI の利用 Policy → 既存 Noctalia Shell Feature          |
| Niri と Noctalia Shell の起動・操作連携 / Home    | 要求する                              | 要求する                      | 要求なし             | Niri Program の任意連携                                  |
| 日本語入力 / NixOS                                | Fcitx5、Hazkey を既定、SKK も利用可能 | Fcitx5、SKK を既定            | 要求なし             | Input Method / SKK の利用 Policy と X12 Host の GUI 条件 |
| libskk の custom rule / Home                      | 配置する                              | 配置する                      | 要求なし             | SKK を利用するユーザー設定の Composition                 |
| X11 互換性 / Home                                 | Xwayland Satellite を要求する         | Xwayland Satellite を要求する | 要求なし             | GUI の X11 互換性の利用 Policy                           |
| NixOS `programs.xwayland`                         | この構成から要求なし                  | この構成から要求なし          | 要求なし             | Satellite とは別の共有 Program として扱う                |
| Ironbar 設定 / Home                               | 要求なし                              | 要求なし                      | 要求なし             | 必要な利用者が Program を明示的に有効化                  |
| OmniWM 設定 / Home                                | 要求なし                              | 要求なし                      | 要求なし             | 必要な利用者が Program を明示的に有効化                  |
| OSK / NixOS・Home                                 | 要求する                              | 要求なし                      | 要求なし             | X12 Host の GUI Policy → 既存 OSK Feature                |
| 自動回転 / NixOS                                  | 要求する                              | 要求なし                      | 要求なし             | X12 Host の GUI Policy → 既存 autoRotation Feature       |
| CLI / Home・NixOS、ネットワーク・遠隔接続 / NixOS | 維持する                              | 維持する                      | 維持する             | 既存の基盤・利用側 Profile                               |

- **意図的な変更:** Ironbar / OmniWM の設定を GUI の既定構成から外す。Program 自体は削除せず、必要時は明示的に有効化できるようにする。両者の新しい Feature や自動起動は追加しない。
- **意図的な変更:** 復旧用 TTY から NixOS の GUI 入力方法、および X12 の Hazkey / OSK / 自動回転の要求を除く。GUI 側ではこれらの既存機能を維持する。
- **維持する依存:** SKK の `Rule = "custom"` と、Home の libskk custom rule 配置を対にする。X12 も SKK を併用するため配置が必要である。OSK は NixOS の Fcitx addon と Home の wvkbd・toggle の両側を構成する。
- **入力方法の評価対象:** Home の Fcitx5 Program は追加 Package 用であり、GUI の日本語入力の提供元ではない。現在は両 Host とも追加 Package が空であるため、その Program の有効フラグだけを機能維持の判定に使わない。NixOS の入力方法・addon・設定と Home の custom rule を検証する。
- **X11 互換性の評価対象:** Satellite 自体が必要な Xwayland を含むことをロック済み実装で確認する。NixOS `programs.xwayland.enable = false` を全体の X11 非対応の証拠とせず、この構成から明示的な `false` を寄与しない。
- Home 単独 Target は表に示すユーザー設定・Package の提供を担い、別評価の NixOS Target への導入を暗黙に保証しない。組み合わせて利用する Host の両 Target と、組み込み Home Manager の結果を検証する。

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
   - 第5節の確定した Host / Runtime 表を基準に、具体的な要求元・変更ファイル・意図的な変更を移行記録へ追記する。TTY の期待値には復旧用契約を用い、現状の無条件有効化を正解として転記しない。

2. **Contract tests**
   - 新しい `sessionGui` 公開 API の値、無効化の意味、選択の整合性を最小評価テストで定義する。
   - 旧実装の出力をそのまま正として期待値にしない。

3. **Session Composition**
   - 単一の `session` から Compositor / Greeter 設定を生成する。
   - Greeter ごとの起動契約を分離し、セッション選択の不一致をなくす。
   - 明示的な競合を assertion で検出する。

4. **Responsibility extraction**
   - Home の文字列 Program リストを解体し、独立した機能を適切な Feature / Program / Profile に移す。
   - Niri の固定 Noctalia Shell 起動・IPC キーバインドを任意連携へ移し、無効な実装を呼び出す設定が残らないようにする。
   - X11 互換性、AccountsService、no-gui specialisation の責務を分離する。
   - 必要以上に広い横断 refactor に着手しない。

5. **Host / Profile migration**
   - GUI / TTY の Runtime Profile、ThinkPad X12 と aarch64 Linux Host、Home / NixOS の構成を点検する。
   - 第5節の確定表に従い、必要な機能は適切な所有者から要求する。GUI の Niri / Noctalia Shell / 日本語入力 / X11 互換性と、X12 の OSK / 自動回転を維持する。Ironbar / OmniWM の既定の設定配布は除く。
   - TTY でも残っていた NixOS の GUI 入力方法と、X12 の Hazkey / OSK / 自動回転の要求条件を移行する。Home 側の変更だけで移行完了としない。

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
- 生成された Niri 設定に対して、Noctalia Shell 無効時にはその起動・IPC キーバインドがなく、有効時には意図された起動・操作が含まれることを検証する。option 値の確認だけで済ませない。
- Noctalia Shell 連携の有無は Greeter backend に依存せず、Feature 経由と共有 Program の直接有効化のどちらでも最終的な実装状態に従う。
- X11 互換性を要求しない場合、他の利用者の Xwayland 利用を妨げない。
- 両 Linux Host の Home / NixOS と組み込み Home Manager で、第5節の GUI / TTY の確定表に一致する。GUI の日本語入力は X12 の Hazkey と SKK 併用、aarch64 の SKK、両 Host の custom rule 配置まで検証する。
- GUI の Xwayland Satellite と X12 の OSK / 自動回転が維持され、Ironbar / OmniWM の設定が既定では配布されない。両 Program を明示的に有効化した場合は設定を配布できる。
- 両 Linux Host の既定の復旧用 TTY では、移行対象の Profile / Host Policy による Niri / Greeter / Noctalia Shell / Fcitx5 / Hazkey / X11 互換機構 / OSK / 自動回転の要求と生成物が移行表どおり存在せず、NixOS は `multi-user.target` で起動する構成になる。Feature のフラグだけでなく、関連 service・ユーザー設定・追加 Package も検証する。他の利用者が共有 Program を明示的に有効にするケースは別途検証する。
- 復旧用 TTY で既存の CLI、NetworkManager、SSH / Tailscale、ユーザー / 認証設定が維持される。移行対象外の Package を一括して禁止するテストにはしない。
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

- [x] `sessionGui` の責務が「セッションの提供とログイン手段の整合性」に集約される。
- [x] Host 等が公開 API のみでセッションと Greeter を構成できる。
- [x] Niri / Noctalia / tuigreet の間でセッション選択の情報源が一つになる。
- [x] Feature の約束と実効構成が一致し、不一致時は明確に失敗する。
- [x] 入力方法、Panel、OSK、OmniWM はセッション成立に無条件で束縛されない。
- [x] Niri の Noctalia Shell 連携は任意であり、Shell 無効時に起動・操作の呼び出しが生成されない。
- [x] X11 互換性、AccountsService、no-gui specialisation の責務が整理される。
- [x] 共有 Program の非排他的利用が維持される。
- [x] NixOS / Home Manager の独立性を踏まえた Host / Runtime 移行が完了する。
- [x] 両 Linux Host の TTY が GUI 障害時の復旧用契約を満たし、Home / NixOS の移行表と実効構成の検証結果が記録される。
- [x] GUI の機能保持と Ironbar / OmniWM の既定からの除外が、第5節の確定表に従って検証される。
- [x] 追加した評価テストおよび可能な環境でのビルドが検証される。
- [x] 変更理由、意図的な動作差分、未検証事項が記録される。
- [x] 今回不要な汎用抽象化を導入していない。

## 12. 実装 AI の報告形式

1. 発見した**根本原因**と、それに由来する症状。
2. 採用した責務境界と、代替案を選ばなかった理由。
3. 変更した Public API と利用側の移行方法。
4. 内部 Composition の構造と実効構成の検証方法。
5. 変更ファイル・動作差分・権限への影響。
6. 実行した Nix 評価・checks・ビルドの成否。
7. 未解決の事項と、今回の範囲外として残した課題。

**最終判断基準：**「その責務は Feature が公開する振る舞いの一部か、内部実装の詳細か、それとも独立した機能か」。既存ファイル配置や行数削減ではなく、この判断から変更を導くこと。

## 13. 実装・移行記録（2026-11-12〜13）

実装開始時の親 revision は `b4cd87e9`（`main`、`fix glide scroll behavior`）。確定済みの第5節を基準に実装する。仕様書の確定変更は保持し、flake.lock は更新しない。

### 採用した API と責務

- NixOS は `sessionGui.enable`、`session`（`niri` のみ）、`greeter.enable`、`greeter.backend` を提供する。tuigreet 固有の package / user は `greeter.tuigreet` 以下に置く。両 backend は同じ選択セッションから構成する。
- Home は `sessionGui.enable` と `session`（`niri` のみ）から Niri Program のユーザー設定を要求する。NixOS と Home は独立評価のままとする。
- セッションの既定は `niri`、Greeter の既定は有効な `noctalia` とする。現在唯一サポートするセッションと、確定した両 Host の GUI 利用方針に対応する。未対応セッションを受け付ける共通化は行わない。
- Home の文字列 Program リストと Fcitx extras の旧 API は廃止する。追加 Fcitx Package が必要なら既存の `dotfiles.programs.fcitx5` を利用する。Ironbar / OmniWM もそれぞれの Program を直接有効化できる。
- Niri Program の `noctalia.enable` / `noctalia.startup.enable` が任意連携を担う。Greeter backend は参照しない。Shell の実効有効状態と systemd 起動経路を考慮する。
- NixOS の `sessionGui.niri.enable` / `greeter.sessionCommand` / `greeter.package` / `greeter.user` / `xwayland.enable` / `noGuiSpecialisation.enable` は廃止する。古い option を黙って無視する互換処理は設けない。

### 利用側の移行表

| 対象                           | 要求元 / 変更ファイル                                                            | 実装上の扱い                                                                                                                               |
| ------------------------------ | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Niri と Greeter                | `modules/nixos/features/session-gui.nix`                                         | 単一セッション選択、実効構成の assertion、実効 Niri package の launcher                                                                    |
| Niri ユーザー設定              | `modules/home/features/session-gui.nix`、`modules/home/programs/niri`            | Session Composition と条件付き Shell 連携                                                                                                  |
| Fcitx5 / SKK                   | `modules/nixos/base/input-method.nix`、`profiles/variants/session-gui/nixos.nix` | 基盤は opt-in、GUI Profile が要求                                                                                                          |
| libskk custom rule / Satellite | `profiles/variants/session-gui/home.nix`                                         | 両 Host の GUI で独立に要求                                                                                                                |
| X12 Hazkey / OSK / 自動回転    | `profiles/hosts/x86_64-linux-a/{home,nixos}.nix`                                 | `hasGui` に基づく通常優先順位の既定値                                                                                                      |
| Ironbar / OmniWM               | Home Session Composition                                                         | 既定の有効化を除き、既存 Program は保持                                                                                                    |
| 空の Fcitx extras override     | `profiles/systems/x86_64-linux/home.nix`                                         | 旧 API の不要な override を除去                                                                                                            |
| no-gui specialisation          | `modules/nixos/base/boot.nix`、GUI NixOS Profile                                 | `dotfiles.nixos.boot.noGuiSpecialisation.enable` は既定 false、GUI Profile で要求。タグ、`multi-user.target`、tty1 の通常 getty 起動を構成 |
| 復旧用 TTY のブート先          | `profiles/variants/session-tty/nixos.nix`                                        | `multi-user.target` を通常の既定値として設定                                                                                               |
| AccountsService                | ロック済み Noctalia Greeter の上流 module                                        | セッション単体 / tuigreet は要求しない。Noctalia の primary user に対する同期認可を維持                                                    |

表中のパスは `nix/` を基準とする。Noctalia Greeter の `passwordlessSyncUsers` は外観同期操作の認可であり、ログイン認証を緩和する変更は行わない。NetworkManager / SSH / Tailscale / ユーザー / 認証の既存定義は変更しない。

TTY では GUI 入力方法が無効でも、既存 Catppuccin 基盤による非稼働の theme metadata が残る場合がある。移行対象の Fcitx addon・SKK 設定・サービス・生成ファイルの不在を確認し、無関係な Package を一括禁止する根拠にはしない。

no-gui の起動先だけを変更すると、greetd が設定する `autovt@tty1` の mask と、Display Manager 有効時の getty 自動起動抑止が残る。共有 Greeter を強制無効化する代わりに、当該 specialisation の getty target から通常の `getty@tty1.service` を明示的に起動し、最初のコンソールでログインできる構成を保つ。

### 検証記録

| 検証                | 結果 / 範囲                                                                                                                                                   |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `session-gui-nixos` | ビルド成功。7 正常構成、9 不整合構成、未対応 session。最小構成で上流を含む assertion を評価                                                                   |
| `session-gui-home`  | ビルド成功。11 生成 KDL ケースと Home 契約の正常・負例。独立した Shell / Terminal、直接 Program 利用、systemd 起動と opt-out を確認                           |
| `recovery-boot`     | ビルド成功。4 最小構成の全 NixOS assertion、no-gui の tty1 getty、GUI・共有 Xwayland・認証の維持を確認                                                        |
| `session-gui-hosts` | 実構成の評価と native 生成物のビルド成功。Home 8、NixOS 12、組み込み Home 12、no-gui と独立 Xwayland。両 Theme、全 Linux Deployment、GUI / TTY が確定表に一致 |
| Niri の構文         | 単体テストの異なる 5 生成設定、および X12 の実 GUI 生成設定で `niri validate` 成功                                                                            |
| X12 GUI Home 全体   | dark GUI の `activationPackage.drvPath` 評価成功。変更に関連しない Home assertion も含む                                                                      |
| 既存の関連チェック  | `auto-rotation`、`game-home`、`game-nixos` ビルド成功                                                                                                         |
| 静的検査            | 変更した Nix の nixfmt、リポジトリ全体の deadnix / statix 成功                                                                                                |
| 独立レビュー        | 初回の tty1 指摘を修正し、修正後の仕様適合・品質レビュー通過。未解決の指摘なし                                                                                |

登録済みの追加チェックは `nix/checks.nix` から利用できる。

全体の `nix flake check --no-build --no-write-lock-file path:.` は、追加した4チェックの評価を通過した後、`installer-e2e` の ISO / `closure-info` 評価中に `disko.drv` が Nix store で無効というエラーで失敗した。同じ lock の依存と変更前の installer コードだけで作った対照 flake でも、同じ store path のエラーを再現した。今回の refactor から独立した失敗であり、全体チェックが成功したとは扱わない。store 参照が無効になる根本原因は今回未調査とし、installer コードは変更していない。

主要 NixOS Target についても、X12 native と aarch64 qemu の dark GUI / TTY、計4構成の `config.system.build.toplevel.drvPath` 評価が成功した。パッケージ閉包の実ビルドとは区別する。X12 の IPU6 と kernel 6.16 以降の組み合わせに対する上流評価 warning は検証ログに記録した。

```sh
XDG_CACHE_HOME=/tmp/sessiongui-nix-cache direnv exec . nix build --no-link \
  path:.#checks.x86_64-linux.session-gui-nixos \
  path:.#checks.x86_64-linux.session-gui-home \
  path:.#checks.x86_64-linux.recovery-boot \
  path:.#checks.x86_64-linux.session-gui-hosts
```

全 Host 表の検証では対象 module の assertion を実際に評価する。上流の正常時には評価できない遅延エラーメッセージを触らず、無関係な Home の import-from-derivation を強制しないよう、assertion のソース位置で対象を選ぶ。GUI 構成では対象が空にならないことも検証する。最小契約テストは上流を含む assertion を評価する。

ARM の実構成・設定配布は x86 環境からも評価した。生成 KDL のビルドはチェックと同じアーキテクチャの Target に限定し、ARM 用 renderer の実ビルドを x86 で成功したとは扱わない。初期調査時の外部取得障害は再開後の X12 GUI Home 評価では再発せず、キャッシュから取得できた。

実機 / VM のブート、Greeter へのログイン、日本語入力・OSK・センサー回転・Noctalia IPC の操作は未検証。システムや Home Manager の switch、commit、push は行っていない。

実効 Niri の無効化、セッション登録の除去、選択 Greeter や起動コマンドの不一致は契約 assertion で検出する。ただし Noctalia を有効にしたまま `services.greetd.enable = mkForce false` だけを指定した不整合では、ロック済み上流 Noctalia が greetd の既定 user を参照し、先に `attribute 'user' missing` を出す場合がある。Feature 自身の Greeter assertion も false になるが、上流の診断順序は変更していない。負例テストではその user を独立に与え、全 assertion の評価と契約違反の検出を確認する。

## 14. 実効構成の検証漏れの修正（2026-11-14）

前回の完了済み実装を現行の依存関係で再評価し、仕様の実効構成契約に対する2件の検証漏れを修正した。既存のユーザー変更である flake.lock と Emacs 設定は保持した。

| 検証漏れ                                                  | 原因と修正                                                                                                                                                                                       |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Home の Niri 設定配布を無効にしても検証が通る             | Feature は Program の有効フラグだけを検証していた。Niri Program が最終的な `home.file."${config.xdg.configHome}/niri".enable` を検証し、XDG 設定と backing file のどちらからの無効化も検出する。 |
| tuigreet に未定義のカスタムユーザーを指定しても検証が通る | 起動設定と公開 `user` の一致だけを検証していた。tuigreet を要求する Composition で、そのユーザーが `users.users` に存在することを検証する。                                                      |

新しい公開 API は追加していない。Niri の source 上書きと XDG_CONFIG_HOME の変更は引き続き許可する。カスタム Greeter ユーザーは利用側で `users.users` に定義し、この Feature は作成しない。認証・遠隔接続・共有 Program の利用方針は変更していない。

| 検証                      | 結果                                                                                                                                                                                                |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 回帰テストの修正前の失敗  | Home の配布無効化と NixOS の未定義ユーザーについて、それぞれ意図した失敗を確認。                                                                                                                    |
| Home の追加契約           | Feature / Program 直接利用 × XDG / backing file 無効化の4負例。カスタム XDG_CONFIG_HOME と source の上書きは両利用経路で成功。                                                                      |
| NixOS の追加契約          | 未定義カスタムユーザーを拒否し、既存のカスタムユーザー・Package・launcher の正常例を維持。                                                                                                          |
| 修正後の登録済み4チェック | `session-gui-nixos`、`session-gui-home`、`recovery-boot`、`session-gui-hosts` のビルド成功。両 Host の Home / NixOS / 組み込み Home と no-gui を再評価。                                            |
| 静的検査・独立レビュー    | 変更した Nix の nixfmt、全体の deadnix / statix と、今回の修正・全 refactor の独立ソースレビューを通過。未解決の指摘なし。                                                                          |
| 全体の flake 評価         | 追加4チェックを含む評価を通過後、`installer-e2e` の ISO / `closure-info` で `disko.drv` の無効な store path により失敗。現行依存と refactor 前の installer ソースだけの対照構成でも同じ失敗を再現。 |

全体評価のエラーは `/nix/store/nf6fy0hk3h7cjw1ahgdilx447zl15r48-disko.drv` が無効というものだった。対照構成は親 revision `b4cd87e9` から取得した14個の installer / bootstrap / storage / impermanence 関連ファイルだけを使用し、これらが現行と同一であることを照合した。現在の lock に対応する入力で、GUI module を読み込まずに同一 ISO・同一 store path のエラーを再現したため、今回の sessionGui refactor から独立した失敗として扱う。store 参照が無効になる根本原因は未調査であり、全体チェックが成功したとは扱わない。

実機 / VM のブート・ログイン・入力操作は今回も未検証。システムや Home Manager の switch、commit、push は行っていない。
