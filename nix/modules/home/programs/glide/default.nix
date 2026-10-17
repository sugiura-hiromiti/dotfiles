{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.glide;
  shared = import ../firefox-common.nix { inherit pkgs; };
in
{
  options = {
    dotfiles = {
      programs = {
        glide = {
          enable = lib.mkEnableOption "Glide Browser";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      file = {
        "dotfiles/nix/modules/home/programs/glide/config/tsconfig.json".text = builtins.toJSON {
          include = [ "glide.ts" ];
          compilerOptions = {
            target = "ESNext";
            module = "ESNext";
            moduleDetection = "force";
            lib = [
              "DOM"
              "DOM.Iterable"
              "DOM.AsyncIterable"
              "ESNext"
            ];
            types = [ "./glide.d.ts" ];
            strict = true;
            noEmit = true;
            skipLibCheck = true;
            erasableSyntaxOnly = true;
          };
        };
      };
    };
    programs = {
      glide-browser = {
        enable = true;

        inherit (shared) policies;

        configPath = "dotfiles/nix/modules/home/programs/glide/config/glide";

        profiles = {
          dflt = {
            isDefault = true;

            settings = shared.settings // {
              "extensions.autoDisableScopes" = 0;
              "dotfiles.glide.theme" = if config.catppuccin.flavor == "latte" then "light" else "dark";
            };

            extensions = {
              force = true;
              packages = shared.extensions;
            };
          };
        };

        nativeMessagingHosts = [
          pkgs.ff2mpv-rust
        ];
      };
    };

    xdg = {
      configFile = {
        "glide" = {
          source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/nix/modules/home/programs/glide/config";
        };
      };
    };
  };
}
