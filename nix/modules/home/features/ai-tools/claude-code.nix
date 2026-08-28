{
  config,
  lib,
  pkgs,
  ...
}:
let
  aiToolsConfig = config.dotfiles.features.aiTools;
  cfg = aiToolsConfig.claudeCode;

  serenaMcp = config.programs.mcp.servers.serena;
  claudeSerenaMcp = {
    inherit (serenaMcp) command;
    type = "stdio";
    args = serenaMcp.args ++ [
      "--context"
      cfg.mcp.serena.context
      "--project-from-cwd"
    ];
  };
in
{
  options = {
    dotfiles = {
      features = {
        aiTools = {
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
  config = lib.mkIf (aiToolsConfig.enable && cfg.enable) {
    programs = {
      claude-code = {
        enable = true;
        enableMcpIntegration = true;
        mcpServers = {
          serena = claudeSerenaMcp;
        };
        package = cfg.package;
      };
    };
  };
}
