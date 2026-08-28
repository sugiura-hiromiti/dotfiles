# nix-agent + Anvil MCP architecture

Date: 2026-08-29

## Status

Accepted design. Implementation has not started from this revision.

## Goal

Keep the existing centralized MCP registry while making ownership and platform boundaries explicit:

- `mcp-nixos` and Context7 remain managed through `mcp-servers-nix`.
- `JEFF7712/nix-agent` is consumed from its upstream flake, including its package and NixOS module.
- `zawatton/anvil.el` is pinned as a non-flake input and packaged locally only for the integration/runtime wrapper that this repository needs.
- `nix-agent` is advertised to Home Manager MCP clients only for hosts whose domain model says their system target kind is NixOS.
- Anvil remains available when both AI tools and Emacs are enabled.

## Architecture decisions

### 1. Upstream-first nix-agent ownership

Add `nix-agent` as a flake input and consume:

- `inputs.nix-agent.packages.${system}.default`
- `inputs.nix-agent.nixosModules.default`

Do not maintain a repository-local reimplementation of the nix-agent Python package or its privileged NixOS module.

The upstream NixOS module owns:

- installing the nix-agent package into the system,
- setting `NIX_AGENT_FLAKE` through `programs.nix-agent.flake`,
- privileged automation policy,
- switch / dry-activate / rollback / generation-switch authority.

Repository policy owns only the values supplied to that module, including which variant enables it and which account receives privileged automation.

### 2. Domain-driven MCP capability gating

`systemTargetKind` already exists in the host/target domain model and distinguishes `nixos`, `darwin`, or no system target.

Pass `systemTargetKind` through the common special arguments used by Home Manager. Register the `nix-agent` MCP endpoint only when:

```text
systemTargetKind == "nixos"
```

Do not infer this capability from `pkgs.stdenv.isLinux`, `os == "linux"`, hostname, or directory layout. The target/domain model is the source of truth.

The resulting boundary is:

```text
NixOS-backed Home target  -> nix-agent MCP present
Darwin-backed Home target -> nix-agent MCP absent
Home-only target          -> nix-agent MCP absent unless the host domain explicitly has a NixOS system target
```

### 3. Keep the central MCP registry agent-independent

`nix/modules/home/features/ai-tools/mcp.nix` remains the central MCP server registry consumed by Codex and other clients.

It should continue to own registration for:

- mcp-nixos
- Context7
- Serena
- GitHub
- nix-agent, conditionally for NixOS-backed targets
- Anvil endpoints when Emacs is enabled

Client-specific modules such as `codex.nix` and `claude-code.nix` should not duplicate these server definitions unless a client requires a genuine transport/configuration override.

### 4. Separate package selection from package definitions

Preserve the existing meaning of:

```text
nix/pkg/default.nix
```

as the shared Home `home.packages` selection.

Repository-local package definitions belong under:

```text
nix/packages/
```

Therefore:

- remove `nix/pkg/nix-agent.nix`, because upstream owns that package;
- move the Anvil integration derivation to `nix/packages/anvil.nix`.

### 5. Flake-managed Anvil source pinning

Add Anvil as a non-flake input:

```nix
anvil = {
  url = "github:zawatton/anvil.el";
  flake = false;
};
```

The local Anvil derivation receives this source from the flake input rather than calling `fetchFromGitHub` itself.

Responsibilities become:

```text
flake.lock
  -> source revision / source hash ownership

nix/packages/anvil.nix
  -> runtime closure and stdio wrapper ownership

ai-tools/anvil.nix
  -> Emacs/Anvil configuration ownership

ai-tools/mcp.nix
  -> MCP endpoint registration ownership
```

### 6. Anvil full-capability means runtime-operational where practical

Keep the previously accepted policy:

- default modules enabled;
- all optional modules advertised by the pinned Anvil revision enabled;
- separately split `anvil-ide.el` remains deferred;
- `ANVIL_PROFILE=full`;
- both `anvil` and `anvil-emacs-eval` endpoints registered.

However, enabling an optional module is not sufficient if its external runtime dependency is absent.

Audit optional modules for external dependencies and include reproducible Nix dependencies where practical. `pty-broker` is a known required correction: its upstream JavaScript directly requires `node-pty`, so a functional full profile must provide `node-pty` rather than only `node`.

Optional capabilities whose upstream runtime prerequisites cannot reasonably be made reproducible in this repository may remain runtime-conditional, but those exceptions must be explicit rather than accidental.

## Expected repository shape

```text
flake.nix
  inputs.nix-agent
  inputs.anvil

flake.lock

nix/pkg/
  default.nix

nix/packages/
  anvil.nix

nix/modules/home/features/ai-tools/
  mcp.nix
  anvil.nix
  codex.nix
  claude-code.nix

nix/profiles/variants/ai-tools/
  home.nix
  nixos.nix

NixOS module graph
  imports inputs.nix-agent.nixosModules.default
```

The repository-local files below should disappear:

```text
nix/pkg/nix-agent.nix
nix/modules/nixos/features/nix-agent.nix
```

## Configuration flow

### nix-agent

```text
host metadata
  -> systemTargetKind
  -> Home specialArgs
  -> conditional MCP registration

ai-tools NixOS variant
  -> programs.nix-agent.enable
  -> programs.nix-agent.package (upstream/default)
  -> programs.nix-agent.flake
  -> privilegedAutomation.enable = true
  -> privilegedAutomation.user = primary account
```

The repository path used by privileged automation must have one owner. Prefer supplying it through `programs.nix-agent.flake`; do not duplicate `$HOME/dotfiles` construction independently in Home and NixOS modules.

### Anvil

```text
inputs.anvil.outPath
  -> nix/packages/anvil.nix
  -> stdio wrapper + runtime closure
  -> ai-tools/anvil.nix
  -> generated init-anvil.el
  -> central MCP registry
```

## Security model

The accepted trust policy remains broad by design:

- nix-agent privileged automation starts enabled, including switch and rollback;
- Anvil exposes evaluation and mutation-capable tooling;
- MCP clients that receive these endpoints are trusted accordingly.

The hard boundary added by this design is platform/domain scope: nix-agent capability must not be advertised to targets that do not own a NixOS system capability.

## Non-goals

This revision does not:

- adopt `rhblind/emacs-mcp-server`;
- adopt standalone `elisp-dev-mcp`;
- adopt `anvil-ide.el` yet;
- redesign the host/account/target/variant/runtime domain model;
- make package-definition placement a generic repository-wide refactor beyond the Anvil file needed here.

## Follow-up investigation

After the base integrations are operational, evaluate `zawatton/anvil-ide.el` separately for xref, project, imenu, tree-sitter, diagnostics, Info lookup, and worker UI value.

## Acceptance criteria

### Structure

- nix-agent source/package/module ownership comes from the upstream flake.
- no repository-local nix-agent package reimplementation remains.
- no repository-local privileged nix-agent module reimplementation remains.
- Anvil source is pinned by `flake.lock` and its local package definition lives under `nix/packages`.
- `nix/pkg/default.nix` retains its existing shared-package-selection meaning.

### Domain/capability behavior

- NixOS-backed Home targets advertise nix-agent.
- Darwin-backed Home targets do not advertise nix-agent.
- the condition derives from `systemTargetKind`, not platform heuristics.
- mcp-nixos, Context7, Serena, and GitHub remain unchanged in behavior.

### nix-agent behavior

- upstream `programs.nix-agent` module is enabled by the NixOS `ai-tools` variant.
- privileged automation is enabled for the primary account.
- switch, dry-activate, rollback, and generation switching are available as intended.
- flake path configuration is not independently duplicated across Home and NixOS configuration.

### Anvil behavior

- both MCP endpoints initialize successfully against the configured Emacs daemon.
- the accepted full optional-module surface loads without making Emacs startup fail.
- known external runtime requirements, including `node-pty` for `pty-broker`, are either packaged and verified or explicitly documented as unsupported exceptions.

### Verification

- `flake.lock` is updated for both new source inputs.
- formatting and lint checks pass.
- representative NixOS and Home evaluations pass.
- representative Darwin and Home evaluations pass.
- representative Linux and Darwin builds pass where existing CI covers them.
- MCP registration is inspected for at least one NixOS-backed and one Darwin-backed Home target.
- Anvil endpoint startup is smoke-tested; `pty-broker` dependency resolution is tested if that module remains in the full profile.
