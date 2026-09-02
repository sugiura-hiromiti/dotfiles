{
  lib,
  pkgs,
  config,
  systemTargetKind,
  ...
}:
let
  cfg = config.dotfiles.features.aiTools;
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
