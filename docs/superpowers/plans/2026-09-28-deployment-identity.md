# Deployment Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deployment as an explicit system identity dimension so one logical host can safely represent multiple concrete NixOS or Darwin deployment environments without multiplying standalone Home targets.

**Architecture:** Normalize deployments under each host, expand only system targets across deployment identity, and keep existing profile/runtime module composition intact. NixOS readiness moves to the selected deployment's Facter report; NixOS and Darwin builders compose deployment modules directly and publish `/etc/dotfiles/identity.json`. Update and installer selection use the same declared deployment identity but different resolution rules: update may consume installed identity, while installer creation never does.

**Tech Stack:** Nix flakes, NixOS/nix-darwin module systems, Home Manager, NixOS Facter, Nushell, Disko, Preservation, NixOS VM tests, Jujutsu/GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-28-deployment-identity-design.md`

## Global Constraints

- `(host, deployment)` is the deployment identity.
- A system target is deployment identity plus enabled configuration axes.
- Standalone Home targets remain deployment-independent.
- NixOS Facter readiness is deployment-scoped; Darwin has no Facter readiness gate.
- System-update intent is decided before readiness; an unready required NixOS target is an error, never a Home-only fallback.
- Installer packages must be derivable from declared NixOS targets before Facter exists.
- Installer destination selection must never consume the build machine's installed identity.
- Deployment modules are composed directly by NixOS/nix-darwin builders; do not generalize `resolve-profiles.nix`.
- Common installer boot/storage requirements remain assertions on the merged final configuration.
- Invalid explicit host/deployment/target selections fail; do not silently fall back.
- `/etc/dotfiles/identity.json` contains only `host` and `deployment`, follows generation activation/rollback, and is not preserved separately.
- Do not include role cleanup, profile architecture redesign, runtime renaming, or account-semantics changes in this implementation.

## Review Focus

- Installed identity stores the logical host while update indexes by canonical `targetHost`: normalize identity host through the existing alias map before host/deployment equality checks.
- A malformed installed identity must not block a fully explicit `--host ... --deployment ...` update, but must fail when update needs the installed identity to resolve host or deployment.
- A Home-only update must succeed without deployment resolution even when no deployment/default exists.
- A required NixOS system update whose selected deployment is declared but unready must fail before activation and must not fall back to Home Manager.
- A declared-but-unready installer target must remain buildable, and pre-Facter and post-Facter evaluation must use the same exact target name.

---

### Task 1: Introduce the Deployment Domain Model and System Target Identity

**Files:**
- Modify: `nix/lib/hosts.nix`
- Modify: `nix/lib/targets.nix`
- Modify: `nix/lib/target-names.nix`
- Modify: `nix/tests/nixos/readiness.nix`
- Modify: `nix/tests/fixtures/hosts/pending/meta.nix`
- Modify: `nix/tests/fixtures/hosts/ready/meta.nix`
- Create: `nix/tests/fixtures/hosts/multi/meta.nix`
- Create: `nix/tests/fixtures/hosts/multi/deployments/ready/facter.json`
- Modify: `nix/profiles/hosts/aarch64-linux-a/meta.nix`
- Move: `nix/profiles/hosts/aarch64-linux-a/facter.json` → `nix/profiles/hosts/aarch64-linux-a/deployments/parallels/facter.json`
- Modify: `nix/profiles/hosts/aarch64-darwin-a/meta.nix`
- Modify: `nix/profiles/hosts/aarch64-darwin-hiromichisugiura/meta.nix`
- Modify: `nix/flake/default.nix`
- Modify: `nix/flake/installer.nix`
- Modify: `nix/ci/default.nix`
- Modify: `nix/tests/nixos/ci.nix`

**Interfaces:**
- Consumes: existing host `system`, `targets`, accounts, variants, runtime axes.
- Produces:
  - `host.deployments :: attrsOf Deployment`
  - `host.deploymentNames :: [ string ]`
  - `host.defaultDeploymentName :: null | string`
  - `Deployment = { name, modules, facterPath?, facterRelativePath?, facterReady? }`
  - system target config fields `deploymentName`, `deployment`, and selected-target convenience fields `facterPath`, `facterRelativePath`, `facterReady` for NixOS
  - `defaultTarget = { target, hostName, deploymentName ? null } -> string`
  - `mkSystemTargetName` requires `deploymentName`; `mkHomeTargetName` remains unchanged.

- [ ] **Step 1: Write failing host/target assertions**

Update `nix/tests/nixos/readiness.nix` so fixtures prove:

- Facter path is `nix/profiles/hosts/<host>/deployments/<deployment>/facter.json`.
- `pending/vm` is declared and unready.
- `ready/vm` is declared and ready.
- fixture host `multi` has deployments `pending` and `ready`, but only the latter is ready.
- declared system names contain `--deployment-<name>`.
- ready NixOS entries filter by selected deployment Facter.
- Home target count for `multi` is independent of its two deployments.
- `defaultTarget { target = "nixos"; hostName = "multi"; deploymentName = "ready"; }` selects the host's default theme/session for that deployment.

- [ ] **Step 2: Run the deployment/readiness check and verify it fails**

Run:

```bash
nix eval --no-update-lock-file --raw .#checks.aarch64-linux.facter-readiness.drvPath
```

Expected: evaluation fails because host deployment fields and deployment-aware target names do not exist yet.

- [ ] **Step 3: Normalize deployments in `hosts.nix`**

Implement:

- `facterRelativePath = host: deployment: .../deployments/${deployment}/facter.json`.
- `facterPath = host: deployment: hostDir + "/${host}/deployments/${deployment}/facter.json"`.
- `normalizeDeployment name deployment` with `modules = deployment.modules or [ ]`.
- for NixOS deployments, derive Facter fields from `(host, deployment)`.
- `deploymentNames = lib.attrNames deployments`.
- `defaultDeploymentName = meta.defaultDeployment or null`.
- assert every system-capable host has at least one deployment.
- assert a non-null default deployment exists in the host's deployment set.

Do not retain host-owned Facter fields.

- [ ] **Step 4: Expand system targets across deployments in `targets.nix`**

Keep Home enumeration unchanged.

For NixOS/Darwin system targets, apply deployment before runtime context:

```text
host -> deployment -> runtime context -> system target config
```

The selected target config must expose `deploymentName` and `deployment`. For NixOS, copy the selected deployment's Facter fields onto the target config so existing final-configuration consumers can continue reading `config.facterPath` without reintroducing host ownership.

Change readiness filtering to the selected deployment's readiness.

Change `defaultTarget` / `defaultTargetEntry` to the set interface above. A system call without `deploymentName` may use `host.defaultDeploymentName`; if neither exists, assert instead of guessing. Home ignores deployment.

- [ ] **Step 5: Extend public system target naming**

Change `mkSystemTargetName` to emit:

```text
<targetHost>--deployment-<deployment>[--theme-...][--session-...]
```

Keep Home naming byte-for-byte compatible.

- [ ] **Step 6: Migrate current production hosts without changing behavior**

Use:

- `aarch64-linux-a.deployments.parallels.modules = [ ]`
- `aarch64-linux-a.defaultDeployment = "parallels"`
- move its current Facter report into the Parallels deployment path; its report already identifies virtualisation as Parallels.
- both current Darwin hosts: `deployments.native.modules = [ ]`, `defaultDeployment = "native"`.

Update current callers of `defaultTarget` and the default-host installer path so the flake remains evaluable after the signature change. Do not add QEMU to the production host yet; Task 6 adds it after installer selection is deployment-aware.

- [ ] **Step 7: Run focused and no-build verification**

Run:

```bash
nix eval --no-update-lock-file --raw .#checks.aarch64-linux.facter-readiness.drvPath
nix flake check --no-build --no-update-lock-file .
```

Expected: both succeed; public system names now contain deployment segments, while Home names do not.

- [ ] **Step 8: Commit**

```bash
jj commit -m "refactor: add deployment system identity"
```

---

### Task 2: Compose Deployment Modules and Publish Generation Identity

**Files:**
- Create: `nix/configurations/system-identity.nix`
- Modify: `nix/configurations/nixos.nix`
- Modify: `nix/configurations/darwin.nix`
- Modify: `nix/flake/default.nix`
- Modify: `nix/flake/checks.nix`
- Modify: `nix/checks.nix`
- Create: `nix/tests/system/deployment.nix`
- Create: `nix/tests/nixos/deployment-identity-vm.nix`

**Interfaces:**
- Consumes: Task 1 target config with `host`, `deploymentName`, `deployment.modules`.
- Produces:
  - `system-identity.nix { targetConfig } -> NixOS/nix-darwin module`
  - both configuration builders expose internal `modulesFor config` for checks and use it from `build`
  - active system contains `/etc/dotfiles/identity.json` with exactly `{"host": config.host, "deployment": config.deploymentName}`.

- [ ] **Step 1: Add failing composition/identity checks**

Create `nix/tests/system/deployment.nix` to assert against real target entries:

- replacing `entry.config.deployment.modules` with a probe module makes that exact probe appear in `nixos.modulesFor` and `darwin.modulesFor`;
- a built NixOS target's `environment.etc."dotfiles/identity.json".text` parses to only `host` and `deployment`;
- a built Darwin target exposes the same JSON shape;
- no Home target is involved in these assertions.

Add the check to `checks.nix`.

- [ ] **Step 2: Run the new check and verify it fails**

Run:

```bash
nix eval --no-update-lock-file --raw .#checks.aarch64-linux.deployment-model.drvPath
```

Expected: failure because builders do not expose/compose deployment modules or identity yet.

- [ ] **Step 3: Implement `system-identity.nix`**

The module must set only:

```nix
environment.etc."dotfiles/identity.json".text =
  builtins.toJSON {
    host = targetConfig.host;
    deployment = targetConfig.deploymentName;
  };
```

Do not add theme/session/account and do not add Preservation entries.

- [ ] **Step 4: Compose deployment modules in both builders**

Refactor each builder to use an exported `modulesFor config`.

For NixOS and Darwin:

- preserve existing profile/module composition;
- append/include `config.deployment.modules` as system modules;
- include the shared generation identity module;
- do not route deployment modules through `profileModules` or `resolve-profiles.nix`;
- do not rely on module-list order for override semantics.

- [ ] **Step 5: Add the rollback VM test**

Create two minimal NixOS generations using `system-identity.nix`:

- generation A reports `test-host/a`;
- generation B reports `test-host/b`;
- both include NixOS test instrumentation.

In the VM:

1. activate A through the system profile and assert identity A;
2. activate B and assert identity B;
3. run `nixos-rebuild switch --rollback`;
4. assert `/etc/dotfiles/identity.json` reports A again.

This proves identity follows activated generation rather than persistent mutable state.

- [ ] **Step 6: Verify composition and instantiate the VM test**

Run:

```bash
nix eval --no-update-lock-file --raw .#checks.aarch64-linux.deployment-model.drvPath
nix eval --no-update-lock-file --raw .#checks.aarch64-linux.deployment-identity-vm.drvPath
```

Expected: both succeed.

- [ ] **Step 7: Commit**

```bash
jj commit -m "feat: publish active deployment identity"
```

---

### Task 3: Make Update Resolution Deployment-Aware

**Files:**
- Modify: `nix/apps/update/plan.nix`
- Modify: `nix/apps/update/script.nix`
- Modify: `nix/apps/update/update.nu`
- Modify: `nix/apps/update/tests/default.nix`
- Modify: `nix/apps/update/tests/run.sh`

**Interfaces:**
- Consumes: declared target entries from Task 1 and runtime identity from Task 2.
- Produces:
  - update CLI option `--deployment: string`
  - script parameter `identityPath ? "/etc/dotfiles/identity.json"`
  - plan host fields `deployments`, `defaultDeployment`
  - system target index path `[ targetHost deploymentName themeName sessionName ]`
  - target field `ready :: bool` (`true` for Darwin; NixOS from deployment Facter readiness).

- [ ] **Step 1: Extend fixtures with failing resolution cases**

Modify the update test plan so host `test` has declared deployments `qemu` and `parallels`, default `parallels`, and NixOS targets indexed by deployment.

Add test cases for:

- explicit `--host test --deployment qemu` selects qemu;
- explicit unknown deployment errors without fallback;
- identity `test/qemu` selects qemu when deployment is omitted;
- identity host A/qemu is not reused after explicit host B;
- stale deployment in matching identity errors;
- Home-only plan succeeds without deployment;
- NixOS target with `ready = false` errors and does not activate Home;
- malformed identity is ignored when both host and deployment are explicit;
- malformed identity errors when identity is needed;
- logical identity host is normalized through the plan alias map before comparing it with the canonical selected host.

- [ ] **Step 2: Run update-app tests and verify failure**

Run:

```bash
nix build --no-update-lock-file -L .#checks.aarch64-linux.update-operation-consistency
```

Expected: new deployment-resolution cases fail.

- [ ] **Step 3: Extend `plan.nix`**

For system targets:

```text
path = targetHost / deploymentName / themeName / sessionName
```

Keep Home indexing unchanged.

Include all declared system targets in the plan, including unready NixOS targets, and emit `ready` on each target. This allows update to distinguish "declared but unready" from "not declared".

Include each host's declared deployment names and optional default deployment in plan data.

- [ ] **Step 4: Add runtime identity injection to `script.nix`**

Change `mkUpdateScript` to accept:

```nix
{
  source,
  planFile,
  identityPath ? "/etc/dotfiles/identity.json",
}
```

Embed `const IDENTITY = "..."` so tests can point at temporary identity files without redirecting real `/etc`.

- [ ] **Step 5: Implement update resolution in `update.nu`**

Preserve current theme-by-hour and session-by-display behavior.

Resolution order:

1. resolve host: explicit host → installed identity host → `DOTFILES_HOST` → short hostname → full hostname → account default;
2. decide whether system update applies from host system kind + runtime kind, before readiness;
3. only if system update applies, resolve deployment: explicit deployment → matching installed identity deployment → optional default deployment;
4. validate deployment belongs to resolved host;
5. select target by deployment/theme/session;
6. if NixOS target exists but `ready = false`, error before `run-operation`;
7. never fall back to Home because of readiness.

Installed identity handling:

- if no identity file exists, return no identity;
- identity must contain non-empty string `host` and `deployment`;
- normalize identity.host through plan aliases before host/deployment comparison;
- do not read/parse identity when explicit host+deployment makes it unnecessary.

- [ ] **Step 6: Re-run update tests**

Run:

```bash
nix build --no-update-lock-file -L .#checks.aarch64-linux.update-operation-consistency
nix build --no-update-lock-file -L .#checks.aarch64-linux.update-source-pin
```

Expected: PASS; existing source pin, locking, preflight, and activation consistency behavior remains unchanged.

- [ ] **Step 7: Commit**

```bash
jj commit -m "feat: resolve deployment during system updates"
```

---

### Task 4: Generate Installers from Declared Targets and Add Deployment-Aware CLI Selection

**Files:**
- Modify: `nix/flake/installer.nix`
- Modify: `nix/flake/default.nix`
- Modify: `nix/apps/build-installer/build.nu`
- Modify: `nix/apps/build-installer/tests/default.nix`
- Modify: `nix/apps/build-installer/tests/run.sh`
- Modify: `nix/apps/build-installer/tests/fake-nix.sh`

**Interfaces:**
- Consumes: `declaredNixosTargetEntries`, Task 1 `defaultTarget`, host deployment metadata.
- Produces installer package attrs:
  - `installer-<declared-system-target-name>` for every declared NixOS target, ready or not;
  - `installer-selection-<host>--deployment-<deployment>` as the default-axis alias for each declared NixOS deployment;
  - `installer-selection-<host>` only for hosts with `defaultDeployment`.
- Produces build-installer selection modes:
  - `--target TARGET`
  - `--host HOST --deployment DEPLOYMENT`
  - `--host HOST` only when the host has a default deployment.

- [ ] **Step 1: Add failing build-installer selection tests**

Cover:

- exact declared `--target` builds `#installer-<target>`;
- `--host test-host --deployment qemu` builds the selection alias;
- `--host test-host` builds the host default alias;
- `--deployment` without `--host` errors before Nix invocation;
- `--target` combined with host/deployment errors;
- no selection errors;
- an undeclared exact target fails because no `installer-<target>` package exists;
- a fake `/etc/dotfiles/identity.json` on the build machine is never consulted;
- source staging, executable-bit preservation, symlink preservation, ignored/unversioned exclusion, and out-of-checkout temp safety remain unchanged.

- [ ] **Step 2: Run build-installer tests and verify failure**

Run:

```bash
nix build --no-update-lock-file -L .#checks.aarch64-linux.build-installer-source-staging
```

Expected: deployment-aware argument cases fail.

- [ ] **Step 3: Generate installer packages from declared entries**

In `flake/installer.nix`:

- filter `declaredNixosTargetEntries` by per-system architecture;
- build one ISO derivation per declared target using that entry's exact target name and selected deployment Facter path;
- add host/deployment default-axis aliases via `defaultTarget { target = "nixos"; hostName = ...; deploymentName = ...; }`;
- add host-only aliases only when `defaultDeploymentName != null`.

Do not use `readyNixosTargetEntries`.

- [ ] **Step 4: Implement build-installer CLI mode validation**

Keep source staging unchanged.

Map arguments to package refs exactly:

```text
--target T                  -> #installer-T
--host H --deployment D     -> #installer-selection-H--deployment-D
--host H                    -> #installer-selection-H
```

The script must not inspect runtime identity.

- [ ] **Step 5: Re-run installer selection tests**

Run:

```bash
nix build --no-update-lock-file -L .#checks.aarch64-linux.build-installer-source-staging
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
jj commit -m "feat: select installers by deployment target"
```

---

### Task 5: Verify Deployment-Specific Facter Bootstrap End to End

**Files:**
- Modify: `nix/configurations/nixos-bootstrap.nix`
- Modify: `nix/installer/iso.nix`
- Modify: `nix/installer/script.nix`
- Modify: `nix/installer/install.nu`
- Modify: `nix/tests/installer/fixture.nix`
- Modify: `nix/tests/installer/runtime.nix`
- Modify: `nix/tests/installer/run.sh`
- Modify: `nix/tests/installer/e2e.nix`
- Modify as needed: `nix/tests/installer/fixture-contract.nix`, `nix/tests/installer/iso.nix`

**Interfaces:**
- Consumes: exact installer target and selected deployment's `facterRelativePath`.
- Produces: unchanged installer lifecycle, except Facter is written under the selected deployment and every post-Facter selector uses the same target string selected before Facter.

- [ ] **Step 1: Update tests first**

Change installer fixtures to use a deployment-scoped path such as:

```text
nix/profiles/hosts/e2e/deployments/qemu/facter.json
```

Use a target name containing `--deployment-qemu`.

Add assertions that:

- fake Facter receives exactly the deployment path;
- metadata evaluation selector uses the exact target;
- Disko selector uses the exact same target;
- `nixos-install --flake` uses the exact same target;
- changing/creating Facter does not change target identity;
- bootstrap contract still rejects a final configuration whose configured Facter report differs from the selected target's canonical report.

- [ ] **Step 2: Run runtime/fixture checks and verify failure**

Run:

```bash
nix build --no-update-lock-file -L .#checks.aarch64-linux.installer-runtime
nix build --no-update-lock-file -L .#checks.aarch64-linux.installer-fixture
```

Expected: failure until all fixture and contract paths are deployment-aware.

- [ ] **Step 3: Update bootstrap wording and parameter flow**

Keep `hostConfig.facterPath` as the selected system target convenience field introduced in Task 1, but change contract wording from "canonical host facter report" to "canonical deployment facter report".

Pass only the selected deployment's relative path into installer runtime. Do not rediscover deployment from hardware or build-machine state.

- [ ] **Step 4: Preserve exact target through post-Facter evaluation**

Ensure the existing `TARGET` constant is the sole target selector for:

- installer metadata evaluation;
- Disko realization;
- final `nixos-install --flake`.

Facter collection may change readiness but must not rerun target selection.

- [ ] **Step 5: Run installer checks**

Run:

```bash
nix build --no-update-lock-file -L .#checks.aarch64-linux.installer-runtime
nix build --no-update-lock-file -L .#checks.aarch64-linux.installer-fixture
nix eval --no-update-lock-file --option allow-import-from-derivation false --raw .#checks.aarch64-linux.installer-e2e.drvPath
```

Then on a Linux builder/runner:

```bash
nix build --no-update-lock-file -L .#checks.aarch64-linux.installer-e2e
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
jj commit -m "test: verify deployment facter bootstrap"
```

---

### Task 6: Add the QEMU Production Deployment, Update Documentation/CI, and Run Full Verification

**Files:**
- Modify: `nix/profiles/hosts/aarch64-linux-a/meta.nix`
- Create: `nix/profiles/hosts/aarch64-linux-a/deployments/qemu/nixos.nix`
- Modify: `README.org`
- Modify: `flake.nix`
- Regenerate: `.github/workflows/ci.yml`
- Regenerate: `.github/workflows/full-build.yml`
- Regenerate: `.github/workflows/eval-nix-version.yml`
- Modify if generated expectations require it: `nix/tests/nixos/ci.nix`

**Interfaces:**
- Consumes: all prior tasks.
- Produces:
  - production `aarch64-linux-a/parallels` as the ready/default deployment;
  - production `aarch64-linux-a/qemu` as a declared unready deployment;
  - QEMU deployment module enabling `services.qemuGuest.enable = true`;
  - a buildable QEMU installer before its Facter report exists.

- [ ] **Step 1: Add QEMU as a declared unready deployment**

In `aarch64-linux-a/meta.nix`:

- keep `defaultDeployment = "parallels"`;
- add `qemu.modules = [ ./deployments/qemu/nixos.nix ]`.

In the QEMU module set:

```nix
services.qemuGuest.enable = true;
```

Do not add a QEMU Facter report to the repository.

- [ ] **Step 2: Add/extend assertions for production declared-vs-ready behavior**

Verify:

- QEMU target names appear in declared entries;
- QEMU target names do not appear in `nixosConfigurations`/ready names before Facter exists;
- `installer-selection-aarch64-linux-a--deployment-qemu` evaluates successfully;
- Parallels remains the host default and remains ready.

- [ ] **Step 3: Update user-facing documentation**

Document:

```text
nix run .#build-installer -- --host aarch64-linux-a --deployment qemu
nix run .#build-installer -- --host aarch64-linux-a --deployment parallels
nix run .#update -- --host aarch64-linux-a --deployment qemu
```

Clarify:

- QEMU system update fails until its Facter report has been captured;
- installer build does not require that report;
- ordinary installed-system update can omit deployment when `/etc/dotfiles/identity.json` resolves it;
- Home-only targets do not include deployment.

Update top-level `flake.nix` comments to match.

- [ ] **Step 4: Regenerate workflows**

Run:

```bash
nix run --no-update-lock-file .#render-workflows
git diff -- .github/workflows
```

Expected: system target references include deployment segments; no unrelated workflow changes.

- [ ] **Step 5: Run final no-build and non-VM verification**

Run:

```bash
nix eval --no-update-lock-file --raw .#checks.aarch64-linux.non-vm.drvPath
nix eval --no-update-lock-file --option allow-import-from-derivation false --raw .#checks.aarch64-linux.installer-e2e.drvPath
nix flake check --no-build --no-update-lock-file .
nix build --no-update-lock-file -L .#checks.aarch64-linux.non-vm
```

On Darwin, also run:

```bash
nix flake check --no-update-lock-file --print-build-logs
```

Expected: PASS.

- [ ] **Step 6: Run VM verification**

On a Linux builder/runner:

```bash
nix build --no-update-lock-file -L .#checks.aarch64-linux.deployment-identity-vm
nix build --no-update-lock-file -L .#checks.aarch64-linux.installer-e2e
nix build --no-update-lock-file -L .#checks.aarch64-linux.impermanence-vm
```

Expected: PASS, including identity rollback, installer bootstrap, and existing impermanence lifecycle.

- [ ] **Step 7: Verify generated workflows are clean**

Run:

```bash
nix run --no-update-lock-file .#render-workflows
git diff --exit-code -- .github/workflows
```

Expected: zero diff.

- [ ] **Step 8: Commit**

```bash
jj commit -m "feat: add qemu deployment support"
```

---

## Final Review Checklist

Before branch completion, verify against the spec:

- [ ] Every system-capable production host declares at least one deployment.
- [ ] NixOS Facter reports exist only under deployment-owned paths.
- [ ] Home target names are unchanged by deployment count.
- [ ] System names include deployment before enabled runtime-axis segments.
- [ ] Darwin target generation is deployment-aware but never Facter-gated.
- [ ] Both builders compose deployment modules directly.
- [ ] Runtime identity contains exactly host/deployment and is generation-owned.
- [ ] Update uses installed identity only for the same canonical host.
- [ ] Update decides system intent before readiness and never readiness-falls-back to Home.
- [ ] Installer packages originate from declared targets, including unready targets.
- [ ] Build-installer does not read installed identity.
- [ ] Post-Facter evaluation preserves the pre-Facter target.
- [ ] Existing installer boot/storage assertions still validate merged final configuration.
- [ ] Roles/profile/runtime cleanup is absent from the diff.
