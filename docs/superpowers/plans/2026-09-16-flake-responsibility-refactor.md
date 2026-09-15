# Flake Responsibility Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give flake construction and output assembly clear owners and explicit dependencies while preserving current behavior.

**Architecture:** Ordinary Nix functions build Home Manager, NixOS, and Darwin configurations. Small flake-parts modules publish outputs, connected by one composition root that constructs the existing host/runtime/target helpers.

**Tech Stack:** Nix flakes, flake-parts, Home Manager, NixOS, nix-darwin, treefmt-nix, actions.nix, Jujutsu.

**Spec:** [Approved design](../specs/2026-09-16-flake-responsibility-refactor-design.md)

## Global Constraints

The following requirements are copied from the approved design:

1. Keep inputs, their `follows` relationships, and `flake.lock` unchanged.
2. Preserve every public configuration name and the host-derived supported
   systems. Keep the existing naming, enumeration, validation, and profile
   resolution logic as their single sources of truth.
3. Preserve the three configuration output families, all existing check names,
   `packages.render-workflows`, `apps.update`, `apps.fix`, both development shells,
   and the treefmt formatter.
4. Preserve module list order, profile order, account defaults, argument fields,
   and constructor package sources. Relocated relative paths must still address
   the original module entrypoints and profile directories.
5. Preserve Home Manager's NUR-overlay package import separately from the
   flake-parts package set used for per-system tooling.
6. Keep Home-specific skill paths and system-specific Nix/Nix-agent packages in
   their respective argument paths. Preserve optional `account`/`accountName`
   fields and lazy access to system-specific inputs.
7. Keep recovery selection's existing host/TTY predicate and assertion. Its
   Linux-only consumer must remain lazy when Darwin outputs are evaluated.
8. Preserve checks' references to final `self` configuration outputs and the
   update application's `source = self.outPath` behavior.
9. Keep formatter consumers connected through their per-system
   `config.treefmt.build` values. Import the treefmt flake module once.
10. Preserve generated workflow contents and the existing public commands.

Additional scope boundaries:

- The primary goal is clear ownership and explicit dependencies; easier extension is a secondary benefit.
- Preserve the host/profile model and existing validation rules.
- Supported systems remain derived from hosts: currently `aarch64-linux` and `aarch64-darwin`.
- Do not introduce a custom flake option hierarchy, a broad `_module.args` registry, or another generic context library.
- Existing implementations in `nix/lib/`, `nix/apps/`, `nix/checks.nix`, `nix/ci/`, and the configuration/profile trees retain their ownership.
- This document is a plan. No implementation or configuration activation is part of the planning task.

---

## File ownership and interfaces

All paths below are relative to the repository root.

| File                            | Action | Responsibility / exported interface                                                                                                      |
| ------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `flake.nix`                     | Modify | Existing inputs and `mkFlake` entrypoint                                                                                                 |
| `nix/flake/default.nix`         | Create | `{ inputs, self }: flakeModule`; compose domain helpers, builders, and output modules                                                    |
| `nix/configurations/common.nix` | Create | `{ lib, nix, nix-agent }: { profileModules; commonSpecialArgs; systemSpecialArgs; }`                                                     |
| `nix/configurations/home.nix`   | Create | Explicit input/helper arguments → `{ build = targetConfig: homeConfiguration; }`                                                         |
| `nix/configurations/nixos.nix`  | Create | Explicit input/helper arguments → `{ build = targetConfig: nixosConfiguration; modulesFor = targetConfig: moduleList; }`                 |
| `nix/configurations/darwin.nix` | Create | Explicit input/helper arguments → `{ build = targetConfig: darwinConfiguration; }`                                                       |
| `nix/flake/configurations.nix`  | Create | `{ mkTargetConfigs, home, nixos, darwin }: flakeModule`                                                                                  |
| `nix/flake/formatting.nix`      | Create | `{ treefmt-nix }: flakeModule`                                                                                                           |
| `nix/flake/apps.nix`            | Create | `{ lib, self, hosts, hostNames, mkTargetConfigEntries }: flakeModule`                                                                    |
| `nix/flake/dev-shells.nix`      | Create | `{ lib }: flakeModule`                                                                                                                   |
| `nix/flake/checks.nix`          | Create | `{ lib, self, disko, preservation, mkTargetConfigEntries, targetConfigNamesForSystem, nixosModulesFor, systemSpecialArgs }: flakeModule` |
| `nix/flake/ci.nix`              | Create | `{ lib, hosts, mkTargetConfigEntries, actions-nix }: flakeModule`                                                                        |
| `README.org`                    | Modify | Short architecture and where-to-edit section                                                                                             |

Here `flakeModule` means an ordinary flake-parts module attribute set. Dependencies are supplied through ordinary imports; each module's `perSystem` function receives standard module arguments such as `pkgs`, `system`, and `config`.

`targetConfig` is the existing resolved configuration from `nix/lib/targets.nix`, unchanged. Shared helper signatures remain:

```nix
profileModules = target: targetConfig: moduleList;
commonSpecialArgs = targetConfig: specialArgs;
systemSpecialArgs = targetConfig: specialArgs;
```

These signature examples describe return types; they are not source files.

## Execution and validation conventions

1. Execute the tasks in order. Within Task 2 the builder extractions can be prepared independently; the composition root should have one owner.
2. Read the spec and current `AGENTS.md` before execution. Use an isolated Jujutsu workspace if implementation needs isolation. Use `jj` for history; do not use Git staging to make Nix see new files.
3. Run Nix commands against `path:.` so newly created files are included before a Jujutsu snapshot. Keep baseline evidence and query scripts under `/tmp`, outside the flake source. Enter the temporary helper-tool shell in appendix A before Task 1.
4. If a command fails, retry through `direnv exec .` (or the repository Nix dev shell), then diagnose any persistent failure.
5. Use existing checks and before/after comparisons. This is a structural refactor, so no artificial failing unit tests or permanent tests that mirror module wiring are needed.
6. Keep each task evaluable. After a verified task, in an environment where metadata writes are available, record a separate Jujutsu change:
   ```bash
   jj diff --stat
   jj diff
   jj describe -m 'refactor(nix): extract configuration builders'
   jj new
   ```
   Use each task's suggested description. Keep unrelated working-copy changes out of these changes. If metadata writes are unavailable, retain the edits and report that history was not recorded.
7. Preserve locked dependencies. Do not run `update`, activation, `switch`, or lock-update commands during validation.
8. A baseline failure is evidence of a pre-existing problem, not a passing preservation gate. Record it and distinguish it from any new failure.
9. Run full checks once at the end on each supported platform. Intermediate tasks use the narrower checks listed below.
10. Source changes can change derivation paths, notably `self.outPath` consumers. Compare public names and semantic values strictly; inspect unexpected derivation differences without requiring universal equality.

### Task 1: Capture the behavior baseline

**Files:**

- Read: `flake.nix`, `flake.lock`, `nix/lib/{hosts,runtime,targets,target-names,resolve-profiles}.nix`.
- Read: `nix/checks.nix`, `nix/apps/update/tests/default.nix`, `nix/ci/default.nix`.
- Create temporary evidence only: the directory recorded in `/tmp/dotfiles-flake-refactor-evidence-path` and scripts defined in the validation appendix.
- Test: existing outputs and checks; no repository test files change.

**Interfaces:**

- Consumes: the current locked flake and existing target metadata.
- Produces: baseline output manifest, semantic snapshots, derivation evaluation results, lock/input evidence, and workflow snapshot for later comparisons.

- [ ] **Step 1: Record the starting revision and allocate evidence outside the flake.**

Run from the repository root on each platform. Use a separate evidence directory per checkout/platform.

```bash
jj --ignore-working-copy status
jj --ignore-working-copy log -r @ --no-graph
flake_refactor_evidence=$(mktemp -d /tmp/dotfiles-flake-refactor.XXXXXX)
export flake_refactor_evidence
printf '%s\n' "$flake_refactor_evidence" > /tmp/dotfiles-flake-refactor-evidence-path
cp flake.nix "$flake_refactor_evidence/flake.before.nix"
cp flake.lock "$flake_refactor_evidence/flake.before.lock"
cp -R .github/workflows "$flake_refactor_evidence/workflows.before"
nix eval --impure --raw --expr builtins.currentSystem > "$flake_refactor_evidence/system"
```

Expected: the platform is `aarch64-linux` or `aarch64-darwin`. Save baseline evidence before changing that checkout. Do not overwrite the evidence-path file halfway through a run.

- [ ] **Step 2: Create the temporary query scripts from the validation appendix and run the baseline snapshot.**

```bash
bash "$flake_refactor_evidence/capture.sh" before
```

Expected: complete, valid JSON files for output names, semantic values, and derivation paths; every target matching the local platform evaluates. The output manifest includes all configuration names explicitly, including Home Manager.

- [ ] **Step 3: Establish the existing quick-check and workflow baseline.**

Run the appendix's quick-check commands and workflow renderer comparison before implementation. Store their logs under the evidence directory. Inspect failures before proceeding so pre-existing failures are known.

**Deliverable:** a reproducible baseline on the local platform, with a named route to collect the other platform's baseline and final results through a matching machine or CI. No implementation edits.

### Task 2: Extract shared helpers and configuration builders

**Files:**

- Create: `nix/configurations/common.nix`.
- Create: `nix/configurations/home.nix`.
- Create: `nix/configurations/nixos.nix`.
- Create: `nix/configurations/darwin.nix`.
- Modify: `flake.nix`, currently the helper/builder block between `commonOverlays` and `supportedSystems`.
- Test: baseline capture's target derivations and semantic values.

**Interfaces:**

- Consumes: original input objects and functions from `common.nix` as shown in the code below.
- Produces: `common.{profileModules,commonSpecialArgs,systemSpecialArgs}`, `home.build`, `nixos.{build,modulesFor}`, `darwin.build`.
- `nixos.build` and recovery checks must use the same `nixos.modulesFor` function.

- [ ] **Step 1: Add the common helper module.**

Create `nix/configurations/common.nix`:

```nix
{ lib, nix, nix-agent }:
let
  resolveProfiles = import ../lib/resolve-profiles.nix { inherit lib; };
  profileModules =
    target: config:
    resolveProfiles {
      inherit target;
      inherit (config)
        system
        os
        host
        variantProfiles
        ;
    };
  commonSpecialArgs =
    config:
    {
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
    }
    // lib.optionalAttrs (config ? account) {
      inherit (config) account;
    }
    // lib.optionalAttrs (config ? accountName) {
      inherit (config) accountName;
    };
  systemSpecialArgs =
    config:
    commonSpecialArgs config
    // {
      nixAgentPackage = nix-agent.packages.${config.system}.default;
      nixPackage = nix.packages.${config.system}.default;
    };
in
{
  inherit profileModules commonSpecialArgs systemSpecialArgs;
}
```

The resolver remains in `nix/lib/resolve-profiles.nix` with its existing profile-root calculation and ordering.

- [ ] **Step 2: Add the Home Manager builder.**

Create `nix/configurations/home.nix`:

```nix
{
  nixpkgs,
  nur,
  home-manager,
  catppuccin,
  nix-index-database,
  mcp-servers-nix,
  i-have-adhd,
  interview-me,
  urd,
  profileModules,
  commonSpecialArgs,
}:
let
  commonOverlays = [
    nur.overlays.default
  ];
  pkgsFor =
    system:
    import nixpkgs {
      inherit system;
      overlays = commonOverlays;
    };
in
{
  build =
    config:
    home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsFor config.system;
      extraSpecialArgs = commonSpecialArgs config // {
        iHaveAdhdSkill = i-have-adhd.outPath;
        interviewMeSkill = interview-me.outPath;
        urdSkill = urd.outPath;
      };
      modules = [
        ../home
      ]
      ++ profileModules "home" config
      ++ [
        catppuccin.homeModules.catppuccin
        nix-index-database.homeModules.default
        mcp-servers-nix.homeManagerModules.default
      ];
    };
}
```

`../home` resolves to `nix/home`, not this builder. Retain the NUR package import here; using per-system tooling `pkgs` changes the configuration.

- [ ] **Step 3: Add the NixOS builder and reusable module stack.**

Create `nix/configurations/nixos.nix`:

```nix
{
  lib,
  nixpkgs,
  disko,
  preservation,
  catppuccin,
  nix-agent,
  profileModules,
  systemSpecialArgs,
}:
let
  nixosProfileModule = config: {
    dotfiles.nixos.users.accounts = lib.mkDefault (
      lib.mapAttrs (_: account: {
        description = account.description or null;
        extraGroups = account.extraGroups or [ ];
        authorizedKeys = account.authorizedKeys or [ ];
        inherit (account) uid;
        homeDirectory = account.homeDirectory or null;
      }) config.accounts.users
    );
  };
  modulesFor =
    config:
    [
      disko.nixosModules.disko
      preservation.nixosModules.default
      (nixosProfileModule config)
      ../nixos/configuration.nix
    ]
    ++ profileModules "nixos" config
    ++ [
      catppuccin.nixosModules.catppuccin
      nix-agent.nixosModules.default
    ];
in
{
  inherit modulesFor;
  build =
    config:
    nixpkgs.lib.nixosSystem {
      inherit (config) system;
      specialArgs = systemSpecialArgs config;
      modules = modulesFor config;
    };
}
```

- [ ] **Step 4: Add the Darwin builder.**

Create `nix/configurations/darwin.nix`:

```nix
{
  lib,
  nix-darwin,
  profileModules,
  systemSpecialArgs,
}:
let
  darwinProfileModule = config: {
    dotfiles.darwin = {
      core.primaryUser = lib.mkDefault config.primaryAccountName;
      users.accounts = lib.mkDefault (
        lib.mapAttrs (_: account: {
          uid = account.uid or null;
          homeDirectory = account.homeDirectory or null;
        }) config.accounts.users
      );
    };
  };
in
{
  build =
    config:
    nix-darwin.lib.darwinSystem {
      inherit (config) system;
      specialArgs = systemSpecialArgs config;
      modules = [
        (darwinProfileModule config)
        ../nix-darwin
      ]
      ++ profileModules "darwin" config;
    };
}
```

- [ ] **Step 5: Replace the original helper/builder block with temporary root wiring.**

Replace the contiguous root `let` block from `commonOverlays =` through the end of `darwin-conf`, leaving `supportedSystems` and existing output assembly below it:

```nix
common = import ./nix/configurations/common.nix {
  inherit lib nix nix-agent;
};
home = import ./nix/configurations/home.nix {
  inherit
    nixpkgs
    nur
    home-manager
    catppuccin
    nix-index-database
    mcp-servers-nix
    i-have-adhd
    interview-me
    urd
    ;
  inherit (common) profileModules commonSpecialArgs;
};
nixos = import ./nix/configurations/nixos.nix {
  inherit lib nixpkgs disko preservation catppuccin nix-agent;
  inherit (common) profileModules systemSpecialArgs;
};
darwin = import ./nix/configurations/darwin.nix {
  inherit lib nix-darwin;
  inherit (common) profileModules systemSpecialArgs;
};
hm-conf = home.build;
nixos-conf = nixos.build;
darwin-conf = darwin.build;
nixosModulesFor = nixos.modulesFor;
inherit (common) systemSpecialArgs;
```

The aliases deliberately keep the existing root consumers intact for this stage. Remove old helper definitions to keep one implementation of each function.

- [ ] **Step 6: Format the touched Nix files and verify configuration preservation.**

```bash
direnv exec . nixfmt flake.nix nix/configurations/*.nix
bash "$flake_refactor_evidence/capture.sh" builders
diff -u "$flake_refactor_evidence/before.outputs.json" "$flake_refactor_evidence/builders.outputs.json"
diff -u "$flake_refactor_evidence/before.semantic.json" "$flake_refactor_evidence/builders.semantic.json"
```

Expected: names and semantic values match; all local target derivations evaluate. Inspect module order and all argument keys against `flake.before.nix`. Investigate changed configuration derivations, especially changed package sources or relocated paths.

**Deliverable / history:** `refactor(nix): extract configuration builders`.

### Task 3: Introduce the composition root and configuration output adapter

**Files:**

- Create: `nix/flake/default.nix`.
- Create: `nix/flake/configurations.nix`.
- Modify: `flake.nix`.
- Test: output manifest and all local configuration evaluations.

**Interfaces:**

- Consumes: `common` and builder interfaces from Task 2 and existing `targets.mkTargetConfigs`.
- Produces: `nix/flake/default.nix` as `{ inputs, self }: flakeModule` and the three public configuration families.
- The composition root alone constructs `hostRegistry`, `runtime`, `targets`, and the builders.

- [ ] **Step 1: Add the configuration output adapter.**

Create `nix/flake/configurations.nix`:

```nix
{
  mkTargetConfigs,
  home,
  nixos,
  darwin,
}:
{
  flake = {
    homeConfigurations = mkTargetConfigs "home" home.build;
    nixosConfigurations = mkTargetConfigs "nixos" nixos.build;
    darwinConfigurations = mkTargetConfigs "darwin" darwin.build;
  };
}
```

- [ ] **Step 2: Move the existing output implementation into the composition root while retaining its per-system body temporarily.**

The following relocation script operates on the Task 2 result. Its assertions detect a mismatched starting point. It preserves the existing input declarations exactly and relocates root-relative `./nix/` imports to paths relative to `nix/flake/`. If the execution environment requires a particular file-editing tool, use that tool to apply this exact transformation; the script also serves as an executable specification that can be tried on a temporary copy.

```bash
python3 - <<'PY'
from pathlib import Path

root = Path("flake.nix")
source = root.read_text()
marker = "  outputs =\n"
prefix, outputs = source.split(marker, 1)
args_end = outputs.index("    let\n")
bindings, body = outputs[args_end + len("    let\n"):].split(
    "    in\n    flake-parts.lib.mkFlake { inherit inputs; } ", 1
)
assert body.endswith(";\n}\n")
module = body[:-len(";\n}\n")]
old_import = "        treefmt-nix.flakeModule\n"
assert module.count(old_import) == 1
module = module.replace(old_import, old_import + """        (import ./configurations.nix {
          inherit (targets) mkTargetConfigs;
          inherit home nixos darwin;
        })
""")
start = module.index("      flake = {\n")
end = module.index("      perSystem =", start)
module = module[:start] + module[end:]
bindings = bindings.replace(
    "      inherit (targets) mkTargetConfigs targetConfigNamesForSystem;\n",
    "      inherit (targets) targetConfigNamesForSystem;\n",
)
for alias in (
    "      hm-conf = home.build;\n",
    "      nixos-conf = nixos.build;\n",
    "      darwin-conf = darwin.build;\n",
):
    assert alias in bindings
    bindings = bindings.replace(alias, "")
header = """{ inputs, self }:
let
  inherit (inputs)
    disko
    preservation
    mcp-servers-nix
    nix-agent
    nix
    nixpkgs
    home-manager
    nix-darwin
    catppuccin
    nur
    treefmt-nix
    nix-index-database
    i-have-adhd
    interview-me
    urd
    actions-nix
    ;
"""
composition = header + bindings + "in\n" + module + "\n"
composition = composition.replace("./nix/", "../")
Path("nix/flake/default.nix").write_text(composition)
root.write_text(prefix + """  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      import ./nix/flake { inherit inputs self; }
    );
}
""")
PY
direnv exec . nixfmt flake.nix nix/flake/*.nix
```

At this stage `default.nix` temporarily retains CI data and the existing `perSystem` body. Tasks 4–5 remove these by responsibility. No new temporary repository file is needed.

- [ ] **Step 3: Verify composition and recursive output wiring.**

```bash
bash "$flake_refactor_evidence/capture.sh" composition
diff -u "$flake_refactor_evidence/before.outputs.json" "$flake_refactor_evidence/composition.outputs.json"
diff -u "$flake_refactor_evidence/before.semantic.json" "$flake_refactor_evidence/composition.semantic.json"
```

Expected: unchanged output names and semantic values, with local target derivations still evaluable. The root must call `mkFlake` once, and `nixpkgs.lib` must still supply domain helpers.

**Deliverable / history:** `refactor(nix): introduce flake composition root`.

### Task 4: Extract formatting, apps, and development shells

**Files:**

- Create: `nix/flake/formatting.nix`.
- Create: `nix/flake/apps.nix`.
- Create: `nix/flake/dev-shells.nix`.
- Modify: `nix/flake/default.nix`.
- Test: formatter, both shell derivations, app metadata, update-app tests.

**Interfaces:**

- Consumes: original `self`, host data, `mkTargetConfigEntries`, `treefmt-nix`, and `nixpkgs.lib`.
- Produces: existing `formatter`, `apps.{update,fix}`, and `devShells.{default,nvim}` for each supported system.
- The `config` used by apps and shells is their `perSystem` configuration, so treefmt consumers share `config.treefmt.build`.

- [ ] **Step 1: Add formatting ownership.**

Create `nix/flake/formatting.nix`:

```nix
{ treefmt-nix }:
{
  imports = [ treefmt-nix.flakeModule ];
  perSystem = {
    treefmt.imports = [ ../treefmt.nix ];
  };
}
```

- [ ] **Step 2: Add the app output adapter.**

Create `nix/flake/apps.nix`:

```nix
{
  lib,
  self,
  hosts,
  hostNames,
  mkTargetConfigEntries,
}:
{
  perSystem =
    { config, pkgs, system, ... }:
    {
      apps = {
        update = import ../apps/update {
          inherit lib pkgs system hosts hostNames mkTargetConfigEntries;
          source = self.outPath;
        };
        fix = import ../apps/fix {
          inherit lib pkgs;
          formatter = config.treefmt.build.wrapper;
        };
      };
    };
}
```

- [ ] **Step 3: Add development-shell ownership.**

Create `nix/flake/dev-shells.nix`:

```nix
{ lib }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      formatters = import ../formatters { inherit lib pkgs; };
      repoMaintenancePackages = with pkgs; [
        formatters.editorTools
        deadnix
        nixd
        statix
      ];
      nvimMaintenancePackages = with pkgs; [
        lua-language-server
        luajitPackages.luarocks
        tree-sitter
      ];
    in
    {
      devShells.default = pkgs.mkShell {
        name = "dotfiles-maintenance";
        inputsFrom = [ config.treefmt.build.devShell ];
        packages = repoMaintenancePackages;
      };
      devShells.nvim = pkgs.mkShell {
        name = "dotfiles-nvim";
        inputsFrom = [ config.treefmt.build.devShell ];
        packages = repoMaintenancePackages ++ nvimMaintenancePackages;
      };
    };
}
```

- [ ] **Step 4: Wire the modules and remove the original definitions.**

In `nix/flake/default.nix` replace the direct `treefmt-nix.flakeModule` import with:

```nix
(import ./formatting.nix { inherit treefmt-nix; })
(import ./apps.nix {
  inherit lib self hosts hostNames;
  inherit (targets) mkTargetConfigEntries;
})
(import ./dev-shells.nix { inherit lib; })
```

Delete the original `treefmt`, `apps`, and `devShells` definitions from the remaining `perSystem` body. Delete `formatters`, `repoMaintenancePackages`, and `nvimMaintenancePackages` from its `let`, and remove its now-unused `config` function argument. Retain the checks and CI definitions until Task 5.

- [ ] **Step 5: Verify the shared formatter consumers and app behavior.**

```bash
direnv exec . nixfmt nix/flake/*.nix
bash "$flake_refactor_evidence/capture.sh" tooling
diff -u "$flake_refactor_evidence/before.outputs.json" "$flake_refactor_evidence/tooling.outputs.json"
diff -u "$flake_refactor_evidence/before.semantic.json" "$flake_refactor_evidence/tooling.semantic.json"
```

Run the appendix's quick-check commands. Expected: both shells and the formatter evaluate, app types remain `app`, app programs are valid store paths, and existing update-app tests pass. Inspect `source = self.outPath` and both `config.treefmt.build` consumers directly.

**Deliverable / history:** `refactor(nix): extract flake tooling modules`.

### Task 5: Extract checks and CI; finish the composition root

**Files:**

- Create: `nix/flake/checks.nix`.
- Create: `nix/flake/ci.nix`.
- Modify: `nix/flake/default.nix`.
- Test: output manifest, check derivations, recovery evaluation, rendered workflows.

**Interfaces:**

- Consumes: target enumeration and per-system naming helpers, `nixos.modulesFor`, `common.systemSpecialArgs`, original `self`, external test inputs, hosts, and `actions-nix`.
- Produces: unchanged per-system checks and `packages.render-workflows`.
- Checks retain final `self` references through `nix/checks.nix`; recovery selection remains global and lazy.

- [ ] **Step 1: Add the checks adapter.**

Create `nix/flake/checks.nix`:

```nix
{
  lib,
  self,
  disko,
  preservation,
  mkTargetConfigEntries,
  targetConfigNamesForSystem,
  nixosModulesFor,
  systemSpecialArgs,
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      nixosTargetEntries = mkTargetConfigEntries "nixos";
      recoveryTarget =
        let
          target = lib.findFirst (
            entry: entry.config.targetHost == "aarch64-linux-a" && entry.config.sessionName == "tty"
          ) null nixosTargetEntries;
        in
        assert lib.assertMsg (target != null) "Could not find recovery target aarch64-linux-a / tty";
        target;
    in
    {
      checks = import ../checks.nix {
        inherit
          recoveryTarget
          nixosModulesFor
          systemSpecialArgs
          preservation
          lib
          pkgs
          self
          disko
          ;
        targetConfigNames = {
          home = targetConfigNamesForSystem "home" system;
          nixos = targetConfigNamesForSystem "nixos" system;
          darwin = targetConfigNamesForSystem "darwin" system;
        };
      };
    };
}
```

Do not filter `nixosTargetEntries` to the current system: Darwin still imports this adapter, and the Linux-only consumer in `nix/checks.nix` controls whether the recovery fixture is forced. Keep the predicate, first-match behavior, assertion, and message unchanged.

- [ ] **Step 2: Add CI output ownership.**

Create `nix/flake/ci.nix`:

```nix
{
  lib,
  hosts,
  mkTargetConfigEntries,
  actions-nix,
}:
let
  ciConfig = import ../ci {
    inherit hosts lib mkTargetConfigEntries;
  };
in
{
  perSystem =
    { pkgs, ... }:
    let
      actionsEval = actions-nix.lib.evalModule pkgs ciConfig;
    in
    {
      packages.render-workflows = actionsEval.config.build.renderWorkflows;
    };
}
```

`ciConfig` remains package-independent; `actionsEval` remains inside `perSystem`.

- [ ] **Step 3: Replace the transitional composition root with its final form.**

Set `nix/flake/default.nix` to:

```nix
{ inputs, self }:
let
  inherit (inputs.nixpkgs) lib;
  runtimeContexts = import ../runtime-contexts.nix;
  targetNames = import ../lib/target-names.nix { inherit lib; };
  hostRegistry = import ../lib/hosts.nix {
    inherit lib runtimeContexts;
    hostDir = ../profiles/hosts;
  };
  inherit (hostRegistry) hosts hostNames;
  runtime = import ../lib/runtime.nix {
    inherit lib runtimeContexts;
  };
  targets = import ../lib/targets.nix {
    inherit lib hosts hostNames runtime targetNames;
  };
  common = import ../configurations/common.nix {
    inherit lib;
    inherit (inputs) nix nix-agent;
  };
  home = import ../configurations/home.nix {
    inherit (inputs)
      nixpkgs
      nur
      home-manager
      catppuccin
      nix-index-database
      mcp-servers-nix
      i-have-adhd
      interview-me
      urd
      ;
    inherit (common) profileModules commonSpecialArgs;
  };
  nixos = import ../configurations/nixos.nix {
    inherit lib;
    inherit (inputs) nixpkgs disko preservation catppuccin nix-agent;
    inherit (common) profileModules systemSpecialArgs;
  };
  darwin = import ../configurations/darwin.nix {
    inherit lib;
    inherit (inputs) nix-darwin;
    inherit (common) profileModules systemSpecialArgs;
  };
in
{
  systems = lib.unique (map (host: hosts.${host}.system) hostNames);
  imports = [
    (import ./configurations.nix {
      inherit (targets) mkTargetConfigs;
      inherit home nixos darwin;
    })
    (import ./formatting.nix {
      inherit (inputs) treefmt-nix;
    })
    (import ./apps.nix {
      inherit lib self hosts hostNames;
      inherit (targets) mkTargetConfigEntries;
    })
    (import ./dev-shells.nix { inherit lib; })
    (import ./checks.nix {
      inherit lib self;
      inherit (inputs) disko preservation;
      inherit (targets) mkTargetConfigEntries targetConfigNamesForSystem;
      nixosModulesFor = nixos.modulesFor;
      inherit (common) systemSpecialArgs;
    })
    (import ./ci.nix {
      inherit lib hosts;
      inherit (targets) mkTargetConfigEntries;
      inherit (inputs) actions-nix;
    })
  ];
}
```

Only this file receives the complete `inputs` set. Every imported builder and adapter receives the narrower set in its declared signature. Remove all temporary aliases and the original per-system body.

- [ ] **Step 4: Verify checks, workflow rendering, and cross-platform laziness.**

```bash
direnv exec . nixfmt nix/flake/*.nix
bash "$flake_refactor_evidence/capture.sh" assembled
diff -u "$flake_refactor_evidence/before.outputs.json" "$flake_refactor_evidence/assembled.outputs.json"
diff -u "$flake_refactor_evidence/before.semantic.json" "$flake_refactor_evidence/assembled.semantic.json"
```

Run the workflow comparison and explicit Linux recovery evaluation from the appendix. The snapshot records check names; the final platform gates evaluate and run all checks. On Darwin, the final gate must succeed without trying to build Linux recovery checks. Review that `nix/tests/nixos/machine-recovery.nix` still receives the production `modulesFor` and `systemSpecialArgs` through unchanged `nix/checks.nix`.

**Deliverable / history:** `refactor(nix): extract checks and CI assembly`.

### Task 6: Document ownership and complete both-platform validation

**Files:**

- Modify: `README.org`.
- Review: `flake.nix` and every new file from Tasks 2–5.
- Preserve: `flake.lock`, `.github/workflows/`, all existing domain and implementation modules.
- Test: final baseline comparison, existing quick checks, full checks on both supported platforms.

**Interfaces:**

- Consumes: the final composition root and output adapters.
- Produces: documented ownership and evidence that public behavior remains unchanged.

- [ ] **Step 1: Add a short architecture section to README.org.**

Insert before `* Bootstrap`:

```org
* Flake architecture

=flake.nix= declares inputs and calls flake-parts. =nix/flake/default.nix=
connects host discovery, runtime expansion, target enumeration, configuration
builders, and output modules.

- =nix/configurations/= builds Home Manager, NixOS, and nix-darwin configurations.
  =common.nix= owns shared arguments and the profile-resolution adapter.
  The NixOS builder also exposes the module stack used by recovery tests.
- =nix/flake/= publishes configurations, checks, apps, development shells,
  formatting, and the workflow renderer. Each module declares its dependencies.
- =nix/lib/= owns host normalization, runtime expansion, target naming/enumeration,
  and profile resolution.
- =nix/apps/=, =nix/checks.nix=, and =nix/ci/= retain their existing implementations.
  =nix/home/=, =nix/nixos/=, and =nix/nix-darwin/= remain configuration module entrypoints.

To add a host, edit =nix/profiles/hosts/<host>/meta.nix= and its profiles.
To change a platform's module stack or constructor arguments, edit its builder
in =nix/configurations/=. To change output wiring, edit the corresponding module
in =nix/flake/=. Tool behavior belongs in the existing implementation directories.
```

Retain existing public command examples. Preserve the root overview/usage comments unless a factual adjustment is needed; avoid unrelated comment or input cleanup.

- [ ] **Step 2: Complete final comparisons and quick checks on each platform.**

```bash
bash "$flake_refactor_evidence/capture.sh" final
diff -u "$flake_refactor_evidence/before.outputs.json" "$flake_refactor_evidence/final.outputs.json"
diff -u "$flake_refactor_evidence/before.semantic.json" "$flake_refactor_evidence/final.semantic.json"
cmp "$flake_refactor_evidence/flake.before.lock" flake.lock
python3 - <<'PY'
import os
from pathlib import Path

before = (Path(os.environ["flake_refactor_evidence"]) / "flake.before.nix").read_text()
after = Path("flake.nix").read_text()
assert before.split("  outputs =", 1)[0] == after.split("  outputs =", 1)[0]
PY
```

Expected: equal public names, semantic values, lock file, and pre-output root contents (including input declarations). Inspect differences between `before.derivations.json` and `final.derivations.json` and explain unexpected changes. Run the appendix's quick checks and workflow comparison after the final edits.

- [ ] **Step 3: Run full flake checks on matching Linux and Darwin machines or CI.**

On each platform:

```bash
nix flake check --no-write-lock-file --print-build-logs path:.
```

Expected: success on `aarch64-linux` and `aarch64-darwin`. These checks include every target build on the current supported system and the existing platform-specific tests. Do not substitute `--all-systems` on one machine for native-platform build results. If a platform is unavailable, leave this checkbox open and report the exact outstanding gate.

- [ ] **Step 4: Review scope and record the completion result.**

```bash
jj diff --stat
jj diff
```

Verify:

- Root input declarations and lock file are unchanged.
- Only the root flake, the listed new files, README, and approved planning documents changed.
- All configuration module stacks retain their original order and paths.
- NUR applies only to Home Manager's constructor package import.
- Common optional fields and Home/system argument ownership are intact.
- Recovery tests reuse the production module function and remain Linux-only.
- Apps and checks receive original `self`; formatting consumers use per-system `config`.
- Host-derived systems and target/profile domain logic are unchanged.
- Generated workflow contents are unchanged.

Record platform, starting/final revisions, commands, outcomes, pre-existing failures, and any unexecuted gate. Only claim full behavior-preservation validation once both platform gates pass.

**Deliverable / history:** `docs(nix): document flake ownership and validation`.

## Validation appendix

The following scripts are temporary review evidence, not new repository infrastructure.

### A. Provision the helper interpreter

The repository dev shell does not currently contain Python. Before Task 1, enter a temporary shell using the repository's locked nixpkgs, then run the remaining commands in that shell:

```bash
nix shell --no-write-lock-file --impure --expr \
  '(builtins.getFlake ("path:" + toString ./.)).inputs.nixpkgs.legacyPackages.${builtins.currentSystem}.python3' \
  --command bash
```

This supplies the standard-library-only migration and JSON helper scripts without changing repository dependencies. If the environment makes the default Nix cache read-only, set a writable task cache before the command:

```bash
export XDG_CACHE_HOME="$(mktemp -d /tmp/dotfiles-flake-refactor-cache.XXXXXX)"
```

When resuming in a new shell after Task 1, restore the saved evidence path:

```bash
export flake_refactor_evidence="$(cat /tmp/dotfiles-flake-refactor-evidence-path)"
```

### B. Define the snapshot query and capture command

After allocating `flake_refactor_evidence` in Task 1, create `query.nix`:

```bash
cat > "$flake_refactor_evidence/query.nix" <<'NIX'
{ root, system }:
let
  flake = builtins.getFlake "path:${toString root}";
  lib = flake.inputs.nixpkgs.lib;
  forceDrv = value: value.drvPath;
  forceDrvs = values: builtins.mapAttrs (_: forceDrv) values;
  configurationsFor = values:
    lib.filterAttrs (_: value: value.pkgs.stdenv.hostPlatform.system == system) values;
  packageId = package: {
    name = package.pname or (builtins.parseDrvName package.name).name;
    version = package.version or null;
  };
  linuxHomeGui = flake.homeConfigurations."aarch64-linux-a--account-a--theme-light--session-gui";
  linuxHomeTty = flake.homeConfigurations."aarch64-linux-a--account-a--theme-dark--session-tty";
  linuxNixos = flake.nixosConfigurations."aarch64-linux-a--theme-light--session-gui";
  darwinHome = flake.homeConfigurations."aarch64-darwin-a--account-a--theme-light";
  darwinSystem = flake.darwinConfigurations."aarch64-darwin-a--theme-light";
  skillSummary = home: {
    names = builtins.attrNames home.config.programs.codex.skills;
    pathsEvaluate = builtins.mapAttrs (_: value: builtins.seq (toString value) true)
      home.config.programs.codex.skills;
    urdHasExpectedSuffix = lib.hasSuffix "/skills/urd"
      (toString home.config.programs.codex.skills.urd);
  };
in
{
  inputNames = builtins.attrNames (removeAttrs flake.inputs [ "self" ]);
  publicNames = {
    configurations = {
      home = builtins.attrNames flake.homeConfigurations;
      nixos = builtins.attrNames flake.nixosConfigurations;
      darwin = builtins.attrNames flake.darwinConfigurations;
    };
    systems = {
      checks = builtins.attrNames flake.checks;
      packages = builtins.attrNames flake.packages;
      apps = builtins.attrNames flake.apps;
      devShells = builtins.attrNames flake.devShells;
      formatter = builtins.attrNames flake.formatter;
    };
    currentSystem = {
      checks = builtins.attrNames flake.checks.${system};
      packages = builtins.attrNames flake.packages.${system};
      apps = builtins.attrNames flake.apps.${system};
      devShells = builtins.attrNames flake.devShells.${system};
      hasFormatter = builtins.hasAttr system flake.formatter;
    };
  };
  derivations = {
    homeTargets = forceDrvs
      (builtins.mapAttrs (_: value: value.activationPackage)
        (configurationsFor flake.homeConfigurations));
    nixosTargets = forceDrvs
      (builtins.mapAttrs (_: value: value.config.system.build.toplevel)
        (configurationsFor flake.nixosConfigurations));
    darwinTargets = forceDrvs
      (builtins.mapAttrs (_: value: value.system)
        (configurationsFor flake.darwinConfigurations));
    packages = forceDrvs flake.packages.${system};
    devShells = forceDrvs flake.devShells.${system};
    formatter = forceDrv flake.formatter.${system};
    apps = builtins.mapAttrs (_: app: {
      inherit (app) type;
      description = app.meta.description or null;
      program = app.program;
    }) flake.apps.${system};
  };
  semantics =
    if system == "aarch64-linux" then {
      homeGui = {
        username = linuxHomeGui.config.home.username;
        homeDirectory = linuxHomeGui.config.home.homeDirectory;
        packageSystem = linuxHomeGui.pkgs.stdenv.hostPlatform.system;
        hasNurOverlay = linuxHomeGui.pkgs ? nur;
        catppuccinFlavor = linuxHomeGui.config.catppuccin.flavor;
        themeEnabled = linuxHomeGui.config.dotfiles.features.theme.enable;
        sessionGuiEnabled = linuxHomeGui.config.dotfiles.features.sessionGui.enable;
        nixAgentMcp = linuxHomeGui.config.programs.mcp.servers ? nix-agent;
        codexPackage = packageId linuxHomeGui.config.programs.codex.package;
        skills = skillSummary linuxHomeGui;
      };
      homeTty = {
        catppuccinFlavor = linuxHomeTty.config.catppuccin.flavor;
        sessionGuiEnabled = linuxHomeTty.config.dotfiles.features.sessionGui.enable;
      };
      nixos = {
        userUid = linuxNixos.config.users.users.a.uid;
        userGroups = linuxNixos.config.users.users.a.extraGroups;
        catppuccinFlavor = linuxNixos.config.catppuccin.flavor;
        sessionGuiEnabled = linuxNixos.config.dotfiles.features.sessionGui.enable;
        nixPackage = packageId linuxNixos.config.nix.package;
        nixAgentPackage = packageId linuxNixos.config.programs.nix-agent.package;
        autoUpgradeFlake = linuxNixos.config.system.autoUpgrade.flake;
      };
    } else if system == "aarch64-darwin" then {
      home = {
        username = darwinHome.config.home.username;
        homeDirectory = darwinHome.config.home.homeDirectory;
        packageSystem = darwinHome.pkgs.stdenv.hostPlatform.system;
        hasNurOverlay = darwinHome.pkgs ? nur;
        catppuccinFlavor = darwinHome.config.catppuccin.flavor;
        themeEnabled = darwinHome.config.dotfiles.features.theme.enable;
        nixAgentMcp = darwinHome.config.programs.mcp.servers ? nix-agent;
        codexPackage = packageId darwinHome.config.programs.codex.package;
        skills = skillSummary darwinHome;
      };
      darwin = {
        primaryUser = darwinSystem.config.system.primaryUser;
        hasAccountInKnownUsers = builtins.elem "a" darwinSystem.config.users.knownUsers;
        userUid = darwinSystem.config.users.users.a.uid;
        userHome = darwinSystem.config.users.users.a.home;
        nixPackage = packageId darwinSystem.config.nix.package;
      };
    } else
      throw "Unsupported baseline system: ${system}";
}
NIX
```

The query evaluates every local target's public build derivation path, plus package, app, shell, and formatter entrypoints. The semantic section checks concrete option paths for Home accounts, NUR, GUI/TTY and light/dark behavior, Home skill arguments, and system Nix/Nix-agent package selection. System account defaults are checked on both platforms. All target names are recorded globally.

Create `capture.sh`:

```bash
cat > "$flake_refactor_evidence/capture.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
: "${flake_refactor_evidence:?Restore the evidence directory first}"
stage=${1:?Pass a snapshot name}
export stage
nix eval --json --impure --no-write-lock-file \
  --expr 'import (builtins.toPath (builtins.getEnv "flake_refactor_evidence") + "/query.nix") {
    root = ./.;
    system = builtins.currentSystem;
  }' > "$flake_refactor_evidence/$stage.raw.json"
python3 - <<'PY'
import json
import os
from pathlib import Path

base = Path(os.environ["flake_refactor_evidence"])
stage = os.environ["stage"]
data = json.loads((base / f"{stage}.raw.json").read_text())
sections = {
    "outputs": {
        "inputNames": data["inputNames"],
        "publicNames": data["publicNames"],
    },
    "semantic": data["semantics"],
    "derivations": data["derivations"],
}
for section, value in sections.items():
    (base / f"{stage}.{section}.json").write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n"
    )
PY
SH
```

Expected: every capture finishes successfully and creates three sorted JSON snapshots plus the raw result. `outputs.json` and `semantic.json` must compare equally at every stage. `derivations.json` retains actual paths for investigation; differences require review and are not automatically failures.

Review `derivations.apps`: both app types must be `app`, and their program strings must begin with `/nix/store/`. Do not execute either app for this validation. Inspect the Home skill-path construction in Task 2 against the baseline source; the query also checks skill names, path evaluation, and the URD skill suffix.

The query intentionally does not force all VM-check derivations after every extraction. Task 5 evaluates recovery explicitly, and the final full checks exercise the complete platform-specific set.

### C. Existing quick checks

Run from the repository root, inside the helper-tool shell. The test names below come from `nix/apps/update/tests/default.nix`.

```bash
flake_refactor_system=$(cat "$flake_refactor_evidence/system")
nix build --no-link --no-write-lock-file --print-build-logs \
  "path:.#checks.$flake_refactor_system.deadnix" \
  "path:.#checks.$flake_refactor_system.statix" \
  "path:.#checks.$flake_refactor_system.treefmt" \
  "path:.#checks.$flake_refactor_system.update-source-pin" \
  "path:.#checks.$flake_refactor_system.update-operation-consistency" \
  "path:.#checks.$flake_refactor_system.update-launcher-lock-safety"
nix develop --no-write-lock-file path:.#default --command true
nix develop --no-write-lock-file path:.#nvim --command true
nix build --no-link --no-write-lock-file "path:.#formatter.$flake_refactor_system"
```

`checks.<system>.treefmt` performs the existing formatter CI check. The final command separately validates the public formatter output. Shell commands only enter the shell and exit.

To save a command's output without hiding failures, use Bash `pipefail`:

```bash
set -o pipefail
nix build --no-link --no-write-lock-file --print-build-logs \
  "path:.#checks.$flake_refactor_system.update-source-pin" \
  2>&1 | tee "$flake_refactor_evidence/update-source-pin.log"
```

Use stage-specific log filenames when recording baseline and final runs.

### D. Recovery evaluation and workflow comparison

In Task 5 on Linux, evaluate the existing recovery check:

```bash
nix eval --raw --no-write-lock-file \
  path:.#checks.aarch64-linux.machine-recovery.drvPath
```

This evaluates the production module stack under the existing recovery test overrides. It may take longer than ordinary target evaluation. The final full Linux check builds/runs this test and the other Linux-only checks: `preservation`, `ephemeral-root`, `impermanence`, `storage-provisioning`, `storage-provisioning-vm`, and `impermanence-vm`.

For workflows, after Task 1's snapshot and again at Task 5/final:

```bash
nix run --no-write-lock-file path:.#render-workflows
diff -ru "$flake_refactor_evidence/workflows.before" .github/workflows
```

Expected: no workflow content differences. This invokes the existing generator and may rewrite files locally; retain any discrepancy for review instead of treating regeneration as permission to change CI behavior.

### E. Evidence to report at execution handoff

| Gate                               | Evidence                                                                  |
| ---------------------------------- | ------------------------------------------------------------------------- |
| Public names and supported systems | Equal baseline/final `outputs.json` on both platforms                     |
| Configuration semantics            | Equal baseline/final `semantic.json` on both platforms                    |
| Every target evaluates             | Complete local-platform `derivations.json` on both platforms              |
| Inputs and lock                    | Equal input-prefix comparison and `cmp` of `flake.lock`                   |
| Tooling                            | Quick-check results, two shell entries, formatter build, app metadata     |
| Recovery reuse                     | Reviewed single `modulesFor` function and Linux recovery evaluation/build |
| CI                                 | Empty workflow diff after rendering                                       |
| Full platform checks               | Successful `nix flake check` on aarch64 Linux and aarch64 Darwin          |

Keep platform gates visibly pending if the corresponding machine or CI is unavailable. Do not describe parsing the plan's snippets as successful implementation tests.
