{
  config,
  lib,
  pkgs,
}:
let
  cfg = config.dotfiles.features.aiTools;
  aiToolsLib = import ./ai-tools/lib.nix { inherit pkgs lib; };
  inherit (aiToolsLib) mkGitHubAuthWrappedPackage mkSerenaArgs;
  codexPackage = mkGitHubAuthWrappedPackage {
    package = cfg.codex.package;
    tokenCommand = cfg.mcp.github.tokenCommand;
    tokenEnvVar = cfg.mcp.github.bearerTokenEnvVar;
  };
  serenaCommand = "${cfg.mcp.serena.uvPackage}/bin/uvx";
  codexMcpServers = {
    serena = {
      command = serenaCommand;
      args = mkSerenaArgs {
        packageSpec = cfg.mcp.serena.packageSpec;
        context = cfg.codex.mcp.serena.context;
        projectFromCwd = true;
      };
      startup_timeout_sec = cfg.codex.mcp.serena.startupTimeoutSec;
    };
    github = {
      url = cfg.mcp.github.url;
      bearer_token_env_var = cfg.mcp.github.bearerTokenEnvVar;
    };
  };
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
      "${config.home.homeDirectory}/dotfiles/" = {
        trust_level = "trusted";
      };
      "${config.dotfiles.paths.workspaceRoot}/poison_girl/" = {
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
                startupTimeoutSec = lib.mkOption {
                  type = lib.types.int;
                  default = 30;
                  description = "Serena MCP startup timeout for Codex, in seconds.";
                };
              };
            };
          };
        };
      };
    };
  };
  config = {
    home.packages = lib.optional cfg.codex.acp.enable cfg.codex.acp.package;

    programs.codex = {
      enable = true;
      context = cfg.codex.context;
      settings = lib.recursiveUpdate defaultCodexSettings cfg.codex.settings;
      package = codexPackage;
    };
  };
}
