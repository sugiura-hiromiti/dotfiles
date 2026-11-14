# Repository instructions

- Use `nix flake check --no-update-lock-file path:.` for repository verification.
  Run it without `--no-build` so the registered checks execute.
- Keep Linux CI's existing evaluation plus non-VM build scope. Nix version
  compatibility CI remains evaluation-only.
- If command execution fails and the repository has `flake.nix` at its root,
  retry using Nix's devshell or `direnv exec .`.
- Prefer Jujutsu (`jj`) over Git when the repository is managed with Jujutsu.
- Use Serena when available. Ask for clarification if anything is unclear.
