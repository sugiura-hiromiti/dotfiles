{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.glide;
  shared = import ../browser-common.nix { inherit pkgs; };
in
{
  options.dotfiles.programs.glide.enable = lib.mkEnableOption "Glide Browser";

  config = lib.mkIf cfg.enable {
    programs.glide-browser = {
      enable = true;

      policies = shared.policies;

      profiles.dflt = {
        isDefault = true;

        settings = shared.settings // {
          "extensions.autoDisableScopes" = 0;
        };

        extensions = {
          force = true;
          packages = shared.extensions;
        };
      };

      nativeMessagingHosts = [
        pkgs.ff2mpv-rust
      ];
    };

    xdg.configFile."glide/glide.ts".source = ./config/glide.ts;

    xdg.configFile."glide/tsconfig.json".source = ./config/tsconfig.json;
  };
}
