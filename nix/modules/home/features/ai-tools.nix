{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.aiTools;
  aiToolsLib = import ./ai-tools/lib.nix { inherit pkgs lib; };
  inherit (aiToolsLib) mkGitHubAuthWrappedPackage mkSerenaArgs;

  claudePackage = mkGitHubAuthWrappedPackage {
    package = cfg.claudeCode.package;
    tokenCommand = cfg.mcp.github.tokenCommand;
    tokenEnvVar = cfg.mcp.github.bearerTokenEnvVar;
  };

  serenaCommand = "${cfg.mcp.serena.uvPackage}/bin/uvx";

  claudeMcpServers = {
    serena = {
      type = "stdio";
      command = serenaCommand;
      args = mkSerenaArgs {
        packageSpec = cfg.mcp.serena.packageSpec;
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

in
{
  imports = [
    ./ai-tools/mcp.nix
    ./ai-tools/codex.nix
  ];
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
    ]
  );
}
