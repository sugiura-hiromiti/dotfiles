{
  config,
  lib,
  pkgs,
  ...
}:
let
  aiToolsConfig = config.dotfiles.features.aiTools;
  cfg = aiToolsConfig.claudeCode;
  aiToolsLib = import ./lib.nix { inherit pkgs lib; };
  inherit (aiToolsLib) mkGitHubAuthWrappedPackage mkSerenaArgs;

  claudePackage = mkGitHubAuthWrappedPackage {
    inherit (cfg) package;
    tokenCommand = aiToolsConfig.mcp.github.tokenCommand;
    tokenEnvVar = aiToolsConfig.mcp.github.bearerTokenEnvVar;
  };

  serenaCommand = "${aiToolsConfig.mcp.serena.uvPackage}/bin/uvx";

  claudeMcpServers = {
    serena = {
      type = "stdio";
      command = serenaCommand;
      args = mkSerenaArgs {
        packageSpec = aiToolsConfig.mcp.serena.packageSpec;
        context = cfg.mcp.serena.context;
        projectFromCwd = true;
      };
    };
    github = {
      type = "http";
      url = aiToolsConfig.mcp.github.url;
      headers = {
        Authorization = "Bearer \${${aiToolsConfig.mcp.github.bearerTokenEnvVar}}";
      };
    };
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
        mcpServers = claudeMcpServers;
        package = claudePackage;
      };
    };
  };
}
