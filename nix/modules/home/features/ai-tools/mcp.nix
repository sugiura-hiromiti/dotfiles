{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.dotfiles.features.aiTools;
  emacsEnabled = config.dotfiles.programs.emacs.enable;
  nixAgentPackage = import ../../../../pkg/nix-agent.nix { inherit lib pkgs; };
  anvilPackage = import ../../../../pkg/anvil.nix {
    inherit lib pkgs;
    emacsPackage = config.programs.emacs.package;
  };
  baseMcpServers = {
    nix-agent = {
      command = "${nixAgentPackage}/bin/nix-agent";
      env.NIX_AGENT_FLAKE = "${config.home.homeDirectory}/dotfiles";
    };
  };
  anvilMcpServers = lib.optionalAttrs emacsEnabled {
    anvil = {
      command = "${anvilPackage}/bin/anvil-stdio";
      args = [
        "--server-id=anvil"
        "--init-function=anvil-enable"
        "--stop-function=anvil-disable"
      ];
      env.ANVIL_PROFILE = "full";
    };

    anvil-emacs-eval = {
      command = "${anvilPackage}/bin/anvil-stdio";
      args = [ "--server-id=emacs-eval" ];
      env.ANVIL_PROFILE = "full";
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    programs = {
      mcp = {
        enable = true;
        servers = baseMcpServers // anvilMcpServers;
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
