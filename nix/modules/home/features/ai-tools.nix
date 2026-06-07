{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.aiTools;

  mcpServers =
    lib.optionalAttrs cfg.codex.mcp.serena.enable {
      serena = {
        command = "${cfg.codex.mcp.serena.uvPackage}/bin/uvx";
        args = [
          "--from"
          cfg.codex.mcp.serena.packageSpec
          "serena"
          "start-mcp-server"
          "--context"
          cfg.codex.mcp.serena.context
        ];
        startup_timeout_sec = cfg.codex.mcp.serena.startupTimeoutSec;
      };
    }
    // lib.optionalAttrs cfg.codex.mcp.github.enable {
      github = {
        url = cfg.codex.mcp.github.url;
        bearer_token_env_var = cfg.codex.mcp.github.bearerTokenEnvVar;
      };
    };

  defaultCodexSettings = {
    model = "gpt-5.5";
    model_reasoning_effort = "xhigh";
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
    };
  }
  // lib.optionalAttrs (mcpServers != { }) {
    mcp_servers = mcpServers;
  };
in
{
  options.dotfiles.features.aiTools = {
    enable = lib.mkEnableOption "AI-assisted development tools";

    codex = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to configure Codex.";
      };

      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Codex package. Null uses the Home Manager default.";
      };

      context = lib.mkOption {
        type = lib.types.lines;
        default = ''
          if command execution failed and repository contains flake.nix at root, retry with nix's devshell or execute via `direnv exec`.
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
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to configure the Serena MCP server for Codex.";
          };
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
          context = lib.mkOption {
            type = lib.types.str;
            default = "codex";
            description = "Serena context passed to the MCP server.";
          };
          startupTimeoutSec = lib.mkOption {
            type = lib.types.int;
            default = 30;
            description = "Serena MCP startup timeout in seconds.";
          };
        };

        github = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to configure the GitHub Copilot MCP server for Codex.";
          };
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
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf cfg.codex.enable {
        home.packages = lib.optional cfg.codex.acp.enable cfg.codex.acp.package;

        programs.codex = {
          enable = true;
          context = cfg.codex.context;
          settings = lib.recursiveUpdate defaultCodexSettings cfg.codex.settings;
        }
        // lib.optionalAttrs (cfg.codex.package != null) {
          package = cfg.codex.package;
        };
      })
    ]
  );
}
