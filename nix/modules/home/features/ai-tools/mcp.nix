{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.dotfiles.features.aiTools;
in
{
  config = lib.mkIf cfg.enable {
    programs = {
      mcp = {
        enable = true;
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
