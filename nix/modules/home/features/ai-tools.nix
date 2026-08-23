{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.aiTools;
  mkGitHubAuthWrappedPackage =
    package:
    let
      executable = package.meta.mainProgram;
    in
    pkgs.symlinkJoin {
      pname = "${package.pname or executable}-with-github-token";
      version = lib.getVersion package;
      paths = [ package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram "$out/bin/${executable}" --run ${lib.escapeShellArg ''
           token_env_var=${lib.escapeShellArg cfg.mcp.github.bearerTokenEnvVar}
          if [ -z "$(printenv "$token_env_var")" ]; then
          token="$(${lib.escapeShellArgs cfg.mcp.github.tokenCommand} 2>/dev/null || true)"
          if [ -n "$token" ]; then
          export "$token_env_var=$token"
          fi
          fi
        ''}
      '';
      inherit (package) meta;
    };
  # TODO: そもそもwrapする必要が在るのか再考
  codexPackage = mkGitHubAuthWrappedPackage cfg.codex.package;
  claudePackage = mkGitHubAuthWrappedPackage cfg.claudeCode.package;

  serenaCommand = "${cfg.mcp.serena.uvPackage}/bin/uvx";
  mkSerenaArgs =
    {
      context,
      projectFromCwd ? false,
    }:
    [
      "--from"
      cfg.mcp.serena.packageSpec
      "serena"
      "start-mcp-server"
      "--context"
      context
    ]
    ++ lib.optionals projectFromCwd [ "--project-from-cwd" ];

  codexMcpServers = {
    serena = {
      command = serenaCommand;
      args = mkSerenaArgs {
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

  claudeMcpServers = {
    serena = {
      type = "stdio";
      command = serenaCommand;
      args = mkSerenaArgs {
        context = cfg.claudeCode.mcp.serena.context;
        projectFromCwd = true;
      };
    };
    github = {
      type = "http";
      url = cfg.mcp.github.url;
      headers = {
        Authorization = "Bearer \${${cfg.mcp.github.bearerTokenEnvVar}}";
      };
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
          enable = lib.mkEnableOption "AI-assisted development tools";

          agentSkills = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to install shared agent skills.";
            };

            source = lib.mkOption {
              type = lib.types.path;
              default = ../../../../agents/skills;
              description = "Repository-managed shared agent skills directory.";
            };

            target = lib.mkOption {
              type = lib.types.str;
              default = ".agents/skills";
              description = "Home-relative path where agent skills are exposed.";
            };
          };

          mcp = {
            serena = {
              uvPackage = lib.mkOption {
                type = lib.types.package;
                default = pkgs.uv;
                defaultText = lib.literalExpression "pkgs.uv";
                description = "Package providing uvx for launching Serena.";
              };
              packageSpec = lib.mkOption {
                type = lib.types.str;
                default = "git+https://github.com/oraios/serena";
                description = "uv package spec used to launch Serena.";
              };
            };
            github = {
              url = lib.mkOption {
                type = lib.types.str;
                default = "https://api.githubcopilot.com/mcp";
                description = "GitHub Copilot MCP URL.";
              };
              bearerTokenEnvVar = lib.mkOption {
                type = lib.types.str;
                default = "GITHUB_PAT_TOKEN";
                description = "Environment variable containing the GitHub MCP bearer token.";
              };
              tokenCommand = lib.mkOption {
                type = (lib.types.listOf lib.types.str);
                default = [
                  "${pkgs.gh}/bin/gh"
                  "auth"
                  "token"
                  "--hostname"
                  "github.com"
                ];
                description = ''
                  Command used by the codex and Claude Code wrappers to populate
                  bearerTokenEnvVar when it is not already set
                '';
              };
            };
          };
          claudeCode = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to install Claude Code.";
            };
            package = lib.mkOption {
              type = lib.types.package;
              default = pkgs.claude-code;
              defaultText = lib.literalExpression "pkgs.claude-code";
              description = "Claude Code package";
            };
            mcp = {
              serena = {
                context = lib.mkOption {
                  type = lib.types.str;
                  default = "claude-code";
                  description = "Serena context passed to the Claude Code MCP server.";
                };
              };
            };
          };

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
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        dotfiles = {
          programs = {
            gh = {
              enable = true;
            };
          };
        };
      }

      (lib.mkIf cfg.agentSkills.enable {
        home.file.${cfg.agentSkills.target}.source = cfg.agentSkills.source;
      })

      (lib.mkIf cfg.claudeCode.enable {
        programs.claude-code = {
          enable = true;
          mcpServers = claudeMcpServers;
          package = claudePackage;
        };
      })

      (lib.mkIf cfg.codex.enable {
        home.packages = lib.optional cfg.codex.acp.enable cfg.codex.acp.package;

        programs.codex = {
          enable = true;
          context = cfg.codex.context;
          settings = lib.recursiveUpdate defaultCodexSettings cfg.codex.settings;
          package = codexPackage;
        };
      })
    ]
  );
}
