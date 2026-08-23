{
  lib,
  pkgs,
}:
{
  options = {
    dotfiles = {
      features = {
        aiTools = {
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
        };
      };
    };
  };
}
