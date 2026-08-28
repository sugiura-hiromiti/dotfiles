# nix-agent + Anvil MCP implementation plan

Date: 2026-08-29

## Task 1: Pin upstream packages

Create repository-local Nix package definitions for:

- `JEFF7712/nix-agent` at the selected upstream commit.
- `zawatton/anvil.el` at the selected upstream commit.

Keep the package pins out of `flake.nix` so the existing lockfile does not change. Start fixed-output hashes with `lib.fakeHash`, then replace them with the hashes reported by CI.

## Task 2: Integrate nix-agent

Files:

- `nix/pkg/nix-agent.nix`
- `nix/modules/nixos/features/nix-agent.nix`
- `nix/modules/nixos/default.nix`
- `nix/profiles/variants/ai-tools/nixos.nix`
- `nix/modules/home/features/ai-tools/mcp.nix`

Steps:

1. Package nix-agent using the same Python dependencies and PATH augmentation as upstream.
2. Add an opt-in NixOS feature module for the full privileged automation sudo policy.
3. Enable that feature from the NixOS `ai-tools` variant.
4. Register nix-agent in the central Home Manager MCP registry and pin `NIX_AGENT_FLAKE` to the user's dotfiles checkout.

## Task 3: Integrate Anvil

Files:

- `nix/pkg/anvil.nix`
- `nix/modules/home/features/ai-tools/anvil.nix`
- `nix/modules/home/features/ai-tools.nix`
- `nix/modules/home/features/ai-tools/mcp.nix`
- `nix/modules/home/programs/emacs/default.nix`
- `nix/modules/home/programs/emacs/config/init.el`

Steps:

1. Package the complete Anvil checkout and its stdio bridge.
2. Put Anvil's external runtime dependencies on both the bridge PATH and the Home Manager profile PATH used by the Emacs daemon.
3. Generate `init-anvil.el` with the complete supported optional-module set except the separately split `ide` layer; load `manifest` last and use the `full` profile.
4. Register upstream's two MCP endpoints, `anvil` and `anvil-emacs-eval`.
5. Add Python, JavaScript, and Emacs Lisp tree-sitter grammars required by Anvil structural tools.
6. Make the main Emacs init load `init-anvil` only when present, so profiles without AI tools remain valid.

## Task 4: Verify and finalize hashes

1. Open a PR from the feature branch so the existing CI runs against the exact remote state.
2. Read fixed-output hash mismatch diagnostics and replace each `lib.fakeHash` with its real SRI hash.
3. Re-run CI and fix evaluation/build/lint failures until all representative jobs pass.
4. Review the final diff for accidental MCP duplication or unrelated changes.

## Task 5: Record deferred work

Do not add `anvil-ide.el` in this change. Treat it as a post-install investigation after Anvil has been exercised in real agent sessions.
