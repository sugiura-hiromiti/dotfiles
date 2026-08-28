{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.features.aiTools;
in
{
  imports = [
    ./ai-tools/mcp.nix
    ./ai-tools/anvil.nix
    ./ai-tools/codex.nix
    ./ai-tools/claude-code.nix
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

    ]
  );
}
