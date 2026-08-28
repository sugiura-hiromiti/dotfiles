{
  config,
  lib,
  pkgs,
  iHaveAdhdSkill,
  interviewMeSkill,
  urdSkill,
  ...
}:
let
  aiToolsCfg = config.dotfiles.features.aiTools;
  cfg = aiToolsCfg.codex;
  aiToolsLib = import ./lib.nix { inherit pkgs lib; };
  inherit (aiToolsLib) mkGitHubAuthWrappedPackage mkSerenaArgs;
  codexPackage = mkGitHubAuthWrappedPackage {
    inherit (cfg) package;
    tokenCommand = aiToolsCfg.mcp.github.tokenCommand;
    tokenEnvVar = aiToolsCfg.mcp.github.bearerTokenEnvVar;
  };
  serenaCommand = "${aiToolsCfg.mcp.serena.uvPackage}/bin/uvx";
  codexMcpServers = {
    serena = {
      command = serenaCommand;
      args = mkSerenaArgs {
        packageSpec = aiToolsCfg.mcp.serena.packageSpec;
        context = cfg.mcp.serena.context;
        projectFromCwd = true;
      };
    };
    github = {
      url = aiToolsCfg.mcp.github.url;
      bearer_token_env_var = aiToolsCfg.mcp.github.bearerTokenEnvVar;
    };
  };

  iHaveAdhdOpenaiYaml = builtins.readFile "${iHaveAdhdSkill}/skills/i-have-adhd/agents/openai.yaml";
  iHaveAdhdNeedsImplicitPatch = lib.hasInfix "allow_implicit_invocation: false" iHaveAdhdOpenaiYaml;
  iHaveAdhdAllowsImplicit = lib.hasInfix "allow_implicit_invocation: true" iHaveAdhdOpenaiYaml;
  iHaveAdhdImplicit =
    assert iHaveAdhdNeedsImplicitPatch || iHaveAdhdAllowsImplicit;
    pkgs.runCommand "i-have-adhd-implicit-skill" { } ''
      cp -R ${iHaveAdhdSkill}/skills/i-have-adhd "$out"
      chmod -R u+w "$out"
      ${lib.optionalString iHaveAdhdNeedsImplicitPatch ''
        substituteInPlace "$out/agents/openai.yaml" \
          --replace-fail \
          "allow_implicit_invocation: false" \
          "allow_implicit_invocation: true"
      ''}
    '';

  interviewMeAlways = pkgs.writeTextDir "SKILL.md" (
    builtins.readFile "${interviewMeSkill}/skills/interview-me/SKILL.md"
    + ''

      ## Codex installation policy

      For this installation, apply the interview protocol at the beginning of
      every interactive task, even when the initial request appears clear,
      informational, or mechanical. This policy overrides the "When NOT to
      Use" conditions and loading constraints that would skip an interactive
      task based on its clarity or kind. Run the protocol once per task, not
      again on every follow-up turn. Skip it only when the user explicitly asks
      to skip or end it, or when higher-priority instructions require
      non-interactive execution.
    ''
  );

  defaultCodexSettings = {
    model = "gpt-5.6-sol";
    model_reasoning_effort = "ultra";
    hide_agent_reasoning = true;
    network_access = true;
    approval_policy = "never";
    sandbox_mode = "workspace-write";
    features = {
      web_search_requests = true;
    };
    sandbox_workspace_write = {
      network_access = true;
    };
    tui = {
      notifications = true;
      status_line = [
        "model-with-reasoning"
        "context-remaining"
        "current-dir"
      ];
    };
    projects = {
      "${config.home.homeDirectory}/dotfiles" = {
        trust_level = "trusted";
      };
      "${config.dotfiles.paths.workspaceRoot}/poison_girl" = {
        trust_level = "trusted";
      };
    };
    mcp_servers = codexMcpServers;
  };
in
{
  options = {
    dotfiles = {
      features = {
        aiTools = {
          codex = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to configure Codex.";
            };

            package = lib.mkOption {
              type = lib.types.package;
              default = pkgs.codex;
              description = "Codex package.";
            };

            context = lib.mkOption {
              type = lib.types.lines;
              default = ''
                if command execution failed and repository contains flake.nix at root, retry with nix's devshell or execute via `direnv exec`.
                if the repository is managed with Jujutsu(jj), prefer using jj over git for version-control operations.
                use serena if possible. if anything is unclear, please make sure to ask for clarification.
              '';
              description = "AGENTS.md-style context injected into Codex.";
            };

            settings = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
              description = "Additional Codex settings, recursively merged over the dotfiles defaults.";
            };

            acp = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether to install the Codex ACP package.";
              };
              package = lib.mkOption {
                type = lib.types.package;
                default = pkgs.codex-acp;
                defaultText = lib.literalExpression "pkgs.codex-acp";
                description = "Codex ACP package.";
              };
            };

            mcp = {
              serena = {
                context = lib.mkOption {
                  type = lib.types.str;
                  default = "codex";
                  description = "Serena context passed to the Codex MCP server.";
                };
              };
            };
          };
        };
      };
    };
  };
  config = lib.mkIf (aiToolsCfg.enable && cfg.enable) {
    home = {
      packages = lib.optional cfg.acp.enable cfg.acp.package;
    };

    programs = {
      codex = {
        enable = true;
        settings = lib.recursiveUpdate defaultCodexSettings cfg.settings;
        package = codexPackage;
        skills = {
          i-have-adhd = iHaveAdhdImplicit;
          interview-me = interviewMeAlways;
          urd = "${urdSkill}/skills/urd";
        };
        context = cfg.context + ''
          ## Required global skills

          - Invoke `$i-have-adhd` and apply it to the presentation of every
            user-facing response.
          - Invoke `$interview-me` at the beginning of every interactive task,
            even when the request initially appears clear. Complete its interview
            before planning, implementation, or the final answer. Do not restart
            the interview on each follow-up turn unless the intended outcome
            materially changes.
          - After the requirements are confirmed, invoke `$urd` and keep applying
            it throughout planning, implementation, and verification.
          - `$interview-me` and `$urd` are sequential, not concurrent. If `$urd`
            uncovers a change to the intended outcome, success criteria,
            constraints, or scope, return to `$interview-me`, reconfirm the intent,
            and then resume `$urd`.
          - Skip a skill only when the user explicitly requests it, or when a
            higher-priority instruction makes the skill inapplicable.
        '';
      };
    };
  };
}
