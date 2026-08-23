{
  lib,
  pkgs,
  config,
}:
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
                  (lib.getExe pkgs.gh)
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
  config =
    let
      cfg = config.dotfiles.features.aiTools;
    in
    lib.mkIf cfg.enable (
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
