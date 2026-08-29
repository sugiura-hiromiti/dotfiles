{
  lib,
  pkgs,
  config,
  systemTargetKind,
  ...
}:
let
  cfg = config.dotfiles.features.aiTools;
  emacsEnabled = config.dotfiles.programs.emacs.enable;
  anvilStdio = "${config.xdg.configHome}/emacs/anvil-stdio.sh";
  nixAgentMcpServers = lib.optionalAttrs (systemTargetKind == "nixos") {
    nix-agent = {
      command = "nix-agent";
    };
  };
  anvilMcpServers = lib.optionalAttrs emacsEnabled {
    anvil = {
      command = anvilStdio;
      args = [ "--server-id=anvil" ];
    };

    anvil-emacs-eval = {
      command = anvilStdio;
      args = [ "--server-id=emacs-eval" ];
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    assertions = lib.optionals emacsEnabled [
      {
        assertion = config.programs.mcp.servers.anvil.args == [ "--server-id=anvil" ];
        message = "Anvil MCP server must use only --server-id=anvil; server lifecycle is managed by Emacs.";
      }
    ];

    programs = {
      mcp = {
        enable = true;
        servers = nixAgentMcpServers // anvilMcpServers;
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
