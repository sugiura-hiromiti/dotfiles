# nix-agent + Anvil MCP integration design

Date: 2026-08-29

## Goal

Extend the existing centralized MCP configuration with two additional capabilities:

- `JEFF7712/nix-agent` for operating on the live NixOS/Home Manager configuration.
- `zawatton/anvil.el` as the Emacs-backed agent workbench.

`mcp-nixos` and Context7 are already enabled through `mcp-servers-nix` and remain unchanged.

## Decisions

- Enable nix-agent's full NixOS operational surface from the start, including `switch` and rollback.
- Grant the primary NixOS user the upstream-style NOPASSWD sudo commands required by nix-agent, scoped to the dotfiles flake for activation commands.
- Enable Anvil's default modules plus every optional module advertised by the pinned `anvil.el`, except the separately split `ide` layer.
- Advertise Anvil with `ANVIL_PROFILE=full`.
- Register both upstream-recommended MCP endpoints: `anvil` and `anvil-emacs-eval`.
- Do not install `rhblind/emacs-mcp-server` or standalone `elisp-dev-mcp`.
- Keep `zawatton/anvil-ide.el` as a post-install investigation task.
- Pin nix-agent and Anvil in repository-local Nix packages rather than adding more flake inputs. This keeps `flake.lock` unchanged and keeps source revisions explicit next to their packaging.

## Architecture

### nix-agent

The integration has two layers:

1. Home Manager registers the `nix-agent` stdio MCP server in `programs.mcp.servers` and sets `NIX_AGENT_FLAKE` to `$HOME/dotfiles`.
2. A NixOS feature module grants the primary account the privileged commands used by nix-agent. The feature is enabled only by the NixOS side of the existing `ai-tools` variant.

The sudo policy intentionally mirrors upstream's privileged automation surface:

- `nixos-rebuild dry-activate --flake <dotfiles>*`
- `nixos-rebuild switch --flake <dotfiles>*`
- `nixos-rebuild switch --rollback`
- system-profile generation switching through `nix-env`
- `switch-to-configuration switch`

This is intentionally high authority. The restriction is the command/flake boundary, not an interactive approval gate.

### Anvil

Anvil is pinned as a read-only Nix store checkout. A small wrapper executes upstream `anvil-stdio.sh` with a PATH containing its external runtime dependencies.

When both AI tools and Emacs are enabled, Home Manager:

- installs the Anvil package and external runtime dependencies,
- generates `init-anvil.el`,
- adds the pinned source to Emacs `load-path`,
- enables all supported optional modules except `ide`, with `manifest` loaded last,
- enables buffer-first modification for all major modes,
- registers `anvil` and `anvil-emacs-eval` in the central MCP registry.

Python, JavaScript, and Emacs Lisp tree-sitter grammars are added to the configured Emacs package so Anvil's structural modules can load.

Some optional modules have their own runtime-specific preconditions. The configuration exposes/enables the module surface; modules that upstream itself treats as optional may still report a missing external dependency at runtime rather than preventing Emacs startup.

## Security model

This change deliberately starts broad so the useful agent surface can be observed before reducing it.

- nix-agent can activate and roll back NixOS without a password for the explicitly listed commands.
- Anvil exposes Elisp evaluation and mutation-capable tools through the running Emacs daemon.
- MCP clients using the existing central registry are therefore trusted at roughly the same level as the primary user for these surfaces.

A later hardening pass should be based on actual tool-use traces rather than speculative restrictions.

## Verification

Use the repository's existing CI as the acceptance boundary:

- representative Nix evaluation,
- deadnix/statix/nixfmt lint,
- representative Linux NixOS + Home builds,
- representative Darwin + Home builds.

Source hashes are finalized from fixed-output mismatch diagnostics before the change is considered complete.

## Follow-up investigation

After the four MCPs (`mcp-nixos`, Context7, nix-agent, Anvil) are running in normal workflows, investigate `zawatton/anvil-ide.el` separately. Evaluate whether its xref/project/imenu/treesit/diagnostics/Info and worker UI functionality materially improves the setup beyond Anvil core and existing Emacs tooling.
