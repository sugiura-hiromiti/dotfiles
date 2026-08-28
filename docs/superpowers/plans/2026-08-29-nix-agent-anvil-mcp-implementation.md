# nix-agent + Anvil MCP Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the repository-local nix-agent fork with upstream flake ownership, gate its MCP capability from the target domain model, move Anvil source pinning into `flake.lock`, and make the accepted Anvil full profile runtime-operational including `pty-broker`.

**Architecture:** `nix-agent` is an upstream flake dependency whose package and NixOS module remain upstream-owned; repository policy only selects and configures that module. `anvil.el` is a non-flake source input, while this repository owns only the Anvil runtime wrapper and Emacs integration. Home Manager continues to expose one central agent-independent MCP registry, with nix-agent present only when `systemTargetKind == "nixos"`.

**Tech Stack:** Nix flakes, NixOS modules, Home Manager, flake-parts, mcp-servers-nix, Emacs Lisp, Node.js/npm, `buildNpmPackage`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-29-nix-agent-anvil-mcp-architecture.md`

## Global Constraints

- Preserve the existing centralized MCP registry in `nix/modules/home/features/ai-tools/mcp.nix`.
- Keep `mcp-nixos`, Context7, Serena, and GitHub MCP behavior unchanged.
- Consume `JEFF7712/nix-agent` from its upstream flake package and `nixosModules.default`; do not maintain a local package or privileged-module reimplementation.
- Advertise nix-agent only when `systemTargetKind == "nixos"`; do not use OS/platform heuristics.
- Keep `nix/pkg/default.nix` as shared Home package selection only; repository-local package definitions live under `nix/packages/`.
- Pin `zawatton/anvil.el` as a non-flake input in `flake.lock`.
- Keep `ANVIL_PROFILE=full`, both Anvil MCP endpoints, all optional modules advertised by the pinned revision except separately deferred `anvil-ide.el`, and `manifest` last.
- Make `pty-broker` operational by providing `node-pty`; do not silently leave an enabled-but-broken module.
- Keep nix-agent privileged automation enabled for the primary NixOS account, including switch and rollback.
- Do not add `rhblind/emacs-mcp-server`, standalone `elisp-dev-mcp`, or `anvil-ide.el`.

---

### Task 1: Move source ownership into flake inputs

**Files:**
- Modify: `flake.nix`
- Modify: `flake.lock`
- Modify: `docs/superpowers/specs/2026-08-29-nix-agent-anvil-mcp-design.md`

**Interfaces:**
- Consumes: existing `inputs` and `outputs = inputs@{ ... }` structure in `flake.nix`.
- Produces: `inputs.nix-agent` as a flake input and `inputs.anvil` as a non-flake source input available to later tasks.

- [ ] **Step 1: Record the pre-change failure state**

Run:

```bash
nix flake metadata --json | jq -e '.locks.nodes["nix-agent"] and .locks.nodes.anvil'
```

Expected: FAIL because neither lock node exists yet.

- [ ] **Step 2: Add the two inputs**

Add inside `inputs` in `flake.nix`:

```nix
nix-agent = {
  url = "github:JEFF7712/nix-agent";
};

anvil = {
  url = "github:zawatton/anvil.el";
  flake = false;
};
```

Add `nix-agent` and `anvil` to the `outputs` argument destructuring so later configuration can reference them directly.

- [ ] **Step 3: Update only the new lock inputs**

Run:

```bash
nix flake update nix-agent anvil
```

Expected: `flake.lock` gains `nix-agent` and `anvil` nodes and any upstream dependencies required by nix-agent.

- [ ] **Step 4: Verify source ownership**

Run:

```bash
nix flake metadata --json | jq -e '
  .locks.nodes["nix-agent"].locked.type == "github" and
  .locks.nodes.anvil.locked.type == "github"
'
```

Expected: PASS.

- [ ] **Step 5: Mark the original design document superseded**

At the top of `docs/superpowers/specs/2026-08-29-nix-agent-anvil-mcp-design.md`, add:

```markdown
> **Status:** Superseded by `docs/superpowers/specs/2026-08-29-nix-agent-anvil-mcp-architecture.md`.
```

Do not otherwise rewrite historical content.

- [ ] **Step 6: Commit**

```bash
git add flake.nix flake.lock docs/superpowers/specs/2026-08-29-nix-agent-anvil-mcp-design.md
git commit -m "refactor: move MCP sources to flake inputs"
```

---

### Task 2: Replace the local nix-agent fork with the upstream NixOS module

**Files:**
- Modify: `flake.nix`
- Modify: `nix/profiles/variants/ai-tools/nixos.nix`
- Modify: `nix/modules/nixos/default.nix`
- Delete: `nix/modules/nixos/features/nix-agent.nix`
- Delete: `nix/pkg/nix-agent.nix`

**Interfaces:**
- Consumes: `nix-agent.nixosModules.default` from Task 1; `accounts.primary` and `accounts.users` already passed to profile modules.
- Produces: upstream `programs.nix-agent` configuration with one flake-path owner and full privileged automation.

- [ ] **Step 1: Capture the current local-fork dependency**

Run:

```bash
rg -n 'pkg/nix-agent|features/nix-agent|dotfiles\.features\.nixAgent' nix flake.nix
```

Expected: matches in the local package, local NixOS feature module/import, and AI-tools NixOS variant.

- [ ] **Step 2: Import the upstream module into NixOS configurations**

In `nixos-conf` inside `flake.nix`, append the upstream module to the NixOS module list:

```nix
++ [
  catppuccin.nixosModules.catppuccin
  nix-agent.nixosModules.default
];
```

- [ ] **Step 3: Configure upstream nix-agent from the NixOS AI-tools variant**

Replace `nix/profiles/variants/ai-tools/nixos.nix` with:

```nix
{ accounts, ... }:
let
  primaryUser = accounts.primary;
  primaryAccount = accounts.users.${primaryUser};
  homeDirectory =
    if primaryAccount.homeDirectory != null then
      primaryAccount.homeDirectory
    else
      "/home/${primaryUser}";
in
{
  programs.nix-agent = {
    enable = true;
    flake = "${homeDirectory}/dotfiles";
    privilegedAutomation = {
      enable = true;
      user = primaryUser;
    };
  };
}
```

Use the absolute path as a string. `lib.types.path` accepts absolute string-like paths, so evaluation must not require `/home/<user>/dotfiles` to exist on the CI runner.

- [ ] **Step 4: Remove the repository-local reimplementation**

Remove `./features/nix-agent.nix` from `nix/modules/nixos/default.nix`, then delete:

```text
nix/modules/nixos/features/nix-agent.nix
nix/pkg/nix-agent.nix
```

- [ ] **Step 5: Verify the upstream configuration evaluates**

Run:

```bash
nix eval --json '.#nixosConfigurations.aarch64-linux-a--theme-dark--session-gui.config.programs.nix-agent.enable'
nix eval --json '.#nixosConfigurations.aarch64-linux-a--theme-dark--session-gui.config.programs.nix-agent.privilegedAutomation.enable'
nix eval --raw '.#nixosConfigurations.aarch64-linux-a--theme-dark--session-gui.config.programs.nix-agent.privilegedAutomation.user'
```

Expected:

```text
true
true
a
```

- [ ] **Step 6: Verify the flake path and privileged command surface**

Run:

```bash
nix eval --raw '.#nixosConfigurations.aarch64-linux-a--theme-dark--session-gui.config.programs.nix-agent.flake'
nix eval --json '.#nixosConfigurations.aarch64-linux-a--theme-dark--session-gui.config.security.sudo.extraRules' \
  | jq -e '.. | strings | select(test("dry-activate --flake|switch --flake|switch --rollback|--switch-generation|switch-to-configuration switch"))' >/dev/null
```

Expected: first command prints `/home/a/dotfiles`; second command succeeds.

- [ ] **Step 7: Verify no local fork remains**

Run:

```bash
! rg -n 'pkg/nix-agent|features/nix-agent|dotfiles\.features\.nixAgent' nix flake.nix
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add flake.nix nix/profiles/variants/ai-tools/nixos.nix nix/modules/nixos/default.nix
git add -u nix/modules/nixos/features/nix-agent.nix nix/pkg/nix-agent.nix
git commit -m "refactor: use upstream nix-agent module"
```

---

### Task 3: Gate nix-agent MCP registration from the domain model

**Files:**
- Modify: `flake.nix`
- Modify: `nix/modules/home/features/ai-tools/mcp.nix`

**Interfaces:**
- Consumes: `systemTargetKind` already produced by `nix/lib/hosts.nix` and propagated into each target config by `nix/lib/targets.nix`.
- Produces: Home special argument `systemTargetKind`; conditional `programs.mcp.servers.nix-agent` registration.

- [ ] **Step 1: Demonstrate the current leak into Darwin**

Run:

```bash
nix eval --json '.#homeConfigurations.aarch64-darwin-a--account-a--theme-dark.config.programs.mcp.servers' \
  | jq -e 'has("nix-agent") | not'
```

Expected before the change: FAIL because nix-agent is currently registered on Darwin.

- [ ] **Step 2: Pass the domain value through Home special arguments**

Add `systemTargetKind` to the `inherit (config)` list in `commonSpecialArgs` in `flake.nix`:

```nix
inherit (config)
  accounts
  configName
  hasGui
  host
  hostName
  session
  system
  systemTargetKind
  os
  targetHost
  theme
  ;
```

- [ ] **Step 3: Replace unconditional nix-agent registration with domain gating**

Add `systemTargetKind` to the argument set of `nix/modules/home/features/ai-tools/mcp.nix` and define:

```nix
nixAgentMcpServers = lib.optionalAttrs (systemTargetKind == "nixos") {
  nix-agent = {
    command = "nix-agent";
  };
};
```

Use this set when composing `programs.mcp.servers`. Do not set `NIX_AGENT_FLAKE` in Home Manager; `programs.nix-agent.flake` in the upstream NixOS module is the sole owner of that path.

- [ ] **Step 4: Verify NixOS-backed Home targets advertise nix-agent**

Run:

```bash
nix eval --json '.#homeConfigurations.aarch64-linux-a--account-a--theme-dark--session-gui.config.programs.mcp.servers' \
  | jq -e '."nix-agent".command == "nix-agent"'
```

Expected: PASS.

- [ ] **Step 5: Verify Darwin-backed Home targets do not advertise nix-agent**

Run:

```bash
nix eval --json '.#homeConfigurations.aarch64-darwin-a--account-a--theme-dark.config.programs.mcp.servers' \
  | jq -e 'has("nix-agent") | not'
```

Expected: PASS.

- [ ] **Step 6: Verify existing MCP registrations remain present on both platforms**

Run:

```bash
for target in \
  aarch64-linux-a--account-a--theme-dark--session-gui \
  aarch64-darwin-a--account-a--theme-dark
do
  nix eval --json ".#homeConfigurations.${target}.config.mcp-servers.programs" \
    | jq -e '.nixos.enable and .context7.enable and .serena.enable and .github.enable'
done
```

Expected: both iterations PASS.

- [ ] **Step 7: Commit**

```bash
git add flake.nix nix/modules/home/features/ai-tools/mcp.nix
git commit -m "refactor: gate nix-agent MCP by target kind"
```

---

### Task 4: Move Anvil packaging to flake-managed source ownership

**Files:**
- Create: `nix/packages/anvil.nix`
- Modify: `flake.nix`
- Modify: `nix/modules/home/features/ai-tools/anvil.nix`
- Modify: `nix/modules/home/features/ai-tools/mcp.nix`
- Delete: `nix/pkg/anvil.nix`

**Interfaces:**
- Consumes: `anvil.outPath` from Task 1; configured Emacs package from Home Manager.
- Produces: local Anvil wrapper derivation with source supplied externally, no `fetchFromGitHub` and no fixed-output source hash.

- [ ] **Step 1: Expose the pinned Anvil source to Home modules**

In `hm-conf.extraSpecialArgs` in `flake.nix`, add:

```nix
anvilSrc = anvil.outPath;
```

- [ ] **Step 2: Create the package-definition namespace and source-injected derivation**

Move the current derivation logic into `nix/packages/anvil.nix` and change its function interface to:

```nix
{
  lib,
  pkgs,
  emacsPackage,
  anvilSrc,
}:
```

Replace the existing `fetchFromGitHub` block with:

```nix
src = anvilSrc;
```

Keep the existing stdio wrapper and runtime package list unchanged for this task.

- [ ] **Step 3: Point both Home consumers at the new package definition**

Add `anvilSrc` to the module argument sets in both:

```text
nix/modules/home/features/ai-tools/anvil.nix
nix/modules/home/features/ai-tools/mcp.nix
```

Change each import from:

```nix
../../../../pkg/anvil.nix
```

to:

```nix
../../../../packages/anvil.nix
```

and pass `inherit anvilSrc`.

- [ ] **Step 4: Delete the old package-definition location**

Delete:

```text
nix/pkg/anvil.nix
```

Do not modify `nix/pkg/default.nix`.

- [ ] **Step 5: Verify source hashes disappeared from local Anvil packaging**

Run:

```bash
! rg -n 'fetchFromGitHub|fakeHash|zawatton|22d8f8a7' nix/packages/anvil.nix nix/pkg
```

Expected: PASS.

- [ ] **Step 6: Verify Home evaluation still produces both Anvil endpoints**

Run:

```bash
nix eval --json '.#homeConfigurations.aarch64-linux-a--account-a--theme-dark--session-gui.config.programs.mcp.servers' \
  | jq -e 'has("anvil") and has("anvil-emacs-eval")'
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add flake.nix nix/packages/anvil.nix nix/modules/home/features/ai-tools/anvil.nix nix/modules/home/features/ai-tools/mcp.nix
git add -u nix/pkg/anvil.nix
git commit -m "refactor: source Anvil from flake input"
```

---

### Task 5: Package node-pty for Anvil's PTY broker

**Files:**
- Modify: `nix/packages/anvil.nix`
- Create: `nix/packages/anvil-pty-broker/package-lock.json`
- Modify: `nix/modules/home/features/ai-tools/anvil.nix`

**Interfaces:**
- Consumes: `${anvilSrc}/pty-broker/package.json` and `${anvilSrc}/pty-broker/anvil-pty-broker.js`.
- Produces: `anvilPackage.ptyBrokerScript`, a store path whose adjacent `node_modules/node-pty` resolves successfully from the broker script.

- [ ] **Step 1: Demonstrate the upstream runtime requirement**

Run:

```bash
anvil_src=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.anvil.outPath')
rg -n "require\('node-pty'\)" "$anvil_src/pty-broker/anvil-pty-broker.js"
```

Expected: one match in the broker's `loadPty` function.

- [ ] **Step 2: Generate and commit an npm lock file for the pinned broker dependency**

Run:

```bash
anvil_src=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.anvil.outPath')
tmp=$(mktemp -d)
cp "$anvil_src/pty-broker/package.json" "$tmp/package.json"
cp "$anvil_src/pty-broker/anvil-pty-broker.js" "$tmp/anvil-pty-broker.js"
(
  cd "$tmp"
  npm install --package-lock-only --ignore-scripts
)
mkdir -p nix/packages/anvil-pty-broker
cp "$tmp/package-lock.json" nix/packages/anvil-pty-broker/package-lock.json
rm -rf "$tmp"
```

Expected: the lock file contains a resolved `node_modules/node-pty` entry satisfying upstream's `^1.0.0` dependency.

- [ ] **Step 3: Add a reproducible broker dependency derivation inside `nix/packages/anvil.nix`**

Add a `ptyBroker` let-binding using `pkgs.buildNpmPackage`. Construct its source from the pinned Anvil broker files plus the committed lock file:

```nix
ptyBrokerSource = pkgs.runCommand "anvil-pty-broker-source" { } ''
  mkdir -p "$out"
  cp ${anvilSrc}/pty-broker/package.json "$out/package.json"
  cp ${anvilSrc}/pty-broker/anvil-pty-broker.js "$out/anvil-pty-broker.js"
  cp ${./anvil-pty-broker/package-lock.json} "$out/package-lock.json"
'';

ptyBroker = pkgs.buildNpmPackage {
  pname = "anvil-pty-broker";
  version = "0.1.0";
  src = ptyBrokerSource;
  npmDepsHash = lib.fakeHash;
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/anvil-pty-broker"
    cp anvil-pty-broker.js "$out/share/anvil-pty-broker/"
    cp -a node_modules "$out/share/anvil-pty-broker/"
    runHook postInstall
  '';
};
```

Add `ptyBroker` to `runtimePackages`, and expose:

```nix
passthru = {
  inherit runtimePackages;
  ptyBrokerScript = "${ptyBroker}/share/anvil-pty-broker/anvil-pty-broker.js";
};
```

- [ ] **Step 4: Resolve the npm dependency hash immediately**

Run the representative Linux Home build:

```bash
nix build '.#homeConfigurations.aarch64-linux-a--account-a--theme-dark--session-gui.activationPackage' --no-link
```

Expected on the first run: fixed-output mismatch for `npmDepsHash` showing `got: sha256-...`.

Replace only `npmDepsHash = lib.fakeHash;` with that reported SRI hash, then rerun the same build.

Expected after replacement: the npm dependency fetch/build proceeds without a fake hash.

- [ ] **Step 5: Point Anvil at the packaged broker script**

In the generated `init-anvil.el` text in `nix/modules/home/features/ai-tools/anvil.nix`, add before optional modules are enabled:

```elisp
(setq anvil-pty-broker-node-binary "${pkgs.nodejs}/bin/node")
(setq anvil-pty-broker-script "${anvilPackage.ptyBrokerScript}")
```

Add `pkgs` to this module's argument set if it is not already present.

- [ ] **Step 6: Verify the generated Emacs configuration references the store-owned broker**

Run:

```bash
nix eval --raw '.#homeConfigurations.aarch64-linux-a--account-a--theme-dark--session-gui.config.xdg.configFile."emacs/lisp/init-anvil.el".text' \
  | grep -E 'anvil-pty-broker-(node-binary|script)'
```

Expected: both settings are present and the script points under `/nix/store/...-anvil-pty-broker...`.

- [ ] **Step 7: Smoke-test node-pty resolution**

Extract the generated script path and run the broker long enough to emit its ready frame:

```bash
init=$(nix eval --raw '.#homeConfigurations.aarch64-linux-a--account-a--theme-dark--session-gui.config.xdg.configFile."emacs/lisp/init-anvil.el".text')
script=$(printf '%s\n' "$init" | sed -n 's/.*anvil-pty-broker-script "\([^"]*\)".*/\1/p')
set +e
output=$(timeout 2s node "$script" --port 0 --token smoke --allow bash 2>&1)
status=$?
set -e
test "$status" -eq 124 || test "$status" -eq 0
printf '%s\n' "$output" | grep -q '"ready"'
```

Expected: PASS; in particular, output must not contain `node-pty not installed`.

- [ ] **Step 8: Verify no fake hashes remain**

Run:

```bash
! rg -n 'lib\.fakeHash|fakeSha256|fakeSha512' nix/packages nix/pkg
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add nix/packages/anvil.nix nix/packages/anvil-pty-broker/package-lock.json nix/modules/home/features/ai-tools/anvil.nix
git commit -m "feat: package Anvil PTY broker dependency"
```

---

### Task 6: Validate the full Anvil integration surface

**Files:**
- Modify if required by verified dependency failures only: `nix/packages/anvil.nix`
- Modify if required by verified dependency failures only: `nix/modules/home/features/ai-tools/anvil.nix`

**Interfaces:**
- Consumes: full optional-module list already configured in `init-anvil.el`; runtime closure from Tasks 4-5.
- Produces: an Anvil initialization that loads the accepted module surface without startup-fatal dependency errors.

- [ ] **Step 1: Build the representative Linux Home closure**

Run:

```bash
nix build '.#homeConfigurations.aarch64-linux-a--account-a--theme-dark--session-gui.activationPackage' --no-link
```

Expected: PASS.

- [ ] **Step 2: Inspect the generated optional-module contract**

Run:

```bash
nix eval --raw '.#homeConfigurations.aarch64-linux-a--account-a--theme-dark--session-gui.config.xdg.configFile."emacs/lisp/init-anvil.el".text' \
  | sed -n '/anvil-optional-modules/,/manifest))/p'
```

Expected: the accepted optional module list is present, `ide` is absent, `ide-treesit` is present, and `manifest` is last.

- [ ] **Step 3: Check external commands referenced by the accepted runtime configuration**

Run:

```bash
nix eval --json '.#homeConfigurations.aarch64-linux-a--account-a--theme-dark--session-gui.config.home.packages' >/dev/null
nix build '.#homeConfigurations.aarch64-linux-a--account-a--theme-dark--session-gui.activationPackage' --no-link
```

Then inspect any Anvil startup/runtime error produced by loading `init-anvil.el`. Only add packages when the error identifies a concrete missing external executable/library. Do not remove optional modules to make the build green unless the upstream capability is truly unsupported on the target platform; such an exception must be documented in the architecture spec before proceeding.

- [ ] **Step 4: Batch-load the generated Anvil init using the configured Emacs package**

Run:

```bash
init_file=$(mktemp)
nix eval --raw '.#homeConfigurations.aarch64-linux-a--account-a--theme-dark--session-gui.config.xdg.configFile."emacs/lisp/init-anvil.el".text' > "$init_file"
emacs_bin=$(nix eval --raw '.#homeConfigurations.aarch64-linux-a--account-a--theme-dark--session-gui.config.programs.emacs.package.outPath')/bin/emacs
"$emacs_bin" --batch -Q -l "$init_file" --eval '(princ "anvil-init-ok")'
rm -f "$init_file"
```

Expected: output includes `anvil-init-ok`; no load error terminates Emacs.

- [ ] **Step 5: Commit only if dependency fixes were needed**

If Task 6 required package/config changes:

```bash
git add nix/packages/anvil.nix nix/modules/home/features/ai-tools/anvil.nix docs/superpowers/specs/2026-08-29-nix-agent-anvil-mcp-architecture.md
git commit -m "fix: complete Anvil runtime closure"
```

If no changes were needed, do not create an empty commit.

---

### Task 7: Run repository acceptance checks and runtime smoke tests

**Files:**
- No planned source changes; fix only defects exposed by these checks.

**Interfaces:**
- Consumes: all previous tasks.
- Produces: evidence that the accepted architecture works across NixOS, Home Manager, Darwin evaluation/build coverage, and MCP runtime startup.

- [ ] **Step 1: Run formatting and static checks**

Run:

```bash
nix fmt
nix develop -c deadnix --fail .
nix develop -c statix check .
```

Expected: formatter leaves no diff; deadnix/statix PASS.

- [ ] **Step 2: Run flake evaluation**

Run:

```bash
nix flake check --all-systems --no-build
```

Expected: PASS.

- [ ] **Step 3: Build representative Linux and Darwin outputs covered by the repository**

Run:

```bash
nix build '.#homeConfigurations.aarch64-linux-a--account-a--theme-dark--session-gui.activationPackage' --no-link
nix build '.#nixosConfigurations.aarch64-linux-a--theme-dark--session-gui.config.system.build.toplevel' --no-link
nix build '.#homeConfigurations.aarch64-darwin-a--account-a--theme-dark.activationPackage' --no-link
```

Expected: PASS on a builder capable of each platform; otherwise rely on the matching GitHub Actions runner for the unavailable platform and require that CI job to pass before completion.

- [ ] **Step 4: Re-check MCP capability boundaries from evaluated configuration**

Run:

```bash
nix eval --json '.#homeConfigurations.aarch64-linux-a--account-a--theme-dark--session-gui.config.programs.mcp.servers' \
  | jq -e 'has("nix-agent") and has("anvil") and has("anvil-emacs-eval")'

nix eval --json '.#homeConfigurations.aarch64-darwin-a--account-a--theme-dark.config.programs.mcp.servers' \
  | jq -e '(has("nix-agent") | not) and has("anvil") and has("anvil-emacs-eval")'
```

Expected: both PASS.

- [ ] **Step 5: Smoke-test Anvil against the running Emacs daemon after applying the Home configuration**

After switching the representative Linux Home configuration, run:

```bash
emacsclient --eval '(progn (require (quote anvil)) (anvil-enable) (princ "anvil-enabled"))'
```

Expected: evaluation completes and includes `anvil-enabled` without a startup-fatal error.

Then verify both stdio entrypoints can start and contact the daemon using the commands emitted by:

```bash
nix eval --json '.#homeConfigurations.aarch64-linux-a--account-a--theme-dark--session-gui.config.programs.mcp.servers' \
  | jq '.anvil, ."anvil-emacs-eval"'
```

- [ ] **Step 6: Review the final diff against architecture boundaries**

Run:

```bash
git diff main...HEAD --stat
git diff main...HEAD -- \
  flake.nix flake.lock \
  nix/pkg nix/packages \
  nix/modules/home/features/ai-tools \
  nix/modules/nixos \
  nix/profiles/variants/ai-tools
```

Verify manually:

```text
nix/pkg/default.nix                    unchanged in meaning
nix/pkg/nix-agent.nix                  absent
nix/pkg/anvil.nix                      absent
nix/modules/nixos/features/nix-agent.nix absent
nix/packages/anvil.nix                 present
nix-agent MCP on NixOS-backed Home     present
nix-agent MCP on Darwin-backed Home    absent
Anvil endpoints                        present where Emacs + AI tools are enabled
```

- [ ] **Step 7: Push the feature branch and require CI green**

```bash
git push -u origin HEAD
```

Require the repository's existing CI to pass for evaluation, lint/format, representative Linux/NixOS/Home builds, and Darwin/Home coverage before declaring the work complete.
