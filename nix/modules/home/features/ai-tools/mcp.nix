{
  lib,
  pkgs,
  config,
  mcpServerPackages,
  systemTargetKind,
  ...
}:
let
  cfg = config.dotfiles.features.aiTools;
  # Serena requires MCP SDK 1.28.1 and still imports mcp.server.fastmcp.
  serenaMcp = pkgs.python3Packages.mcp_1.overridePythonAttrs (old: {
    version = "1.28.1";
    src = old.src.override {
      tag = "v1.28.1";
      hash = "sha256-8nifuun7ShtniimsFr9gYPpjwZEM/5E51GDmZRxQGEc=";
    };
  });
  serena = mcpServerPackages.serena.override {
    python3Packages = pkgs.python3Packages // {
      mcp = serenaMcp;
    };
  };
  nixAgentMcpServers = lib.optionalAttrs (systemTargetKind == "nixos") {
    nix-agent = {
      command = "nix-agent";
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    programs = {
      mcp = {
        enable = true;
        servers = nixAgentMcpServers;
      };
    };

    mcp-servers = {
      programs = {
        nixos = {
          enable = true;
        };
        context7 = {
          enable = true;
        };
        serena = {
          enable = true;
          package = serena;
        };
        github = {
          enable = true;
          passwordCommand = {
            GITHUB_PERSONAL_ACCESS_TOKEN = [
              (lib.getExe pkgs.gh)
              "auth"
              "token"
              "--hostname"
              "github.com"
            ];
          };
        };
      };
    };
  };
}
