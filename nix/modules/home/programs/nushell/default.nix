{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.nushell;
  sqliteLibrary = "${pkgs.sqlite.out}/lib/${
    if pkgs.stdenv.hostPlatform.isDarwin then "libsqlite3.dylib" else "libsqlite3.so"
  }";
  nativeCompletions = [
    "jj/jj-completions.nu"
    "cargo/cargo-completions.nu"
    "nix/nix-completions.nu"
    "rg/rg-completions.nu"
    "bat/bat-completions.nu"
  ];
  nativeCompletionConfig = lib.concatMapStringsSep "\n" (
    path: "source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/${path}"
  ) nativeCompletions;
in
{
  options.dotfiles.programs.nushell = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to install and configure Nushell.";
    };

    sqliteLibrary = lib.mkOption {
      type = lib.types.str;
      default = sqliteLibrary;
      defaultText = lib.literalExpression ''
        "''${pkgs.sqlite.out}/lib/''${if pkgs.stdenv.hostPlatform.isDarwin then "libsqlite3.dylib" else "libsqlite3.so"}"
      '';
      description = "SQLite dynamic library path exported for Nushell plugins.";
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      shell.enableNushellIntegration = lib.mkDefault true;
      sessionVariables = {
        CLAP_PATH = lib.mkDefault "~/.nix-profile/lib/clap";
        LIBSQLITE = lib.mkDefault cfg.sqliteLibrary;
        SHELL = lib.mkDefault "${pkgs.nushell}/bin/nu";
      };
      file = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        "nushell_appsupport_config" = {
          target = "Library/Application Support/nushell/config.nu";
          source = ./config/config.nu;
        };
      };
    };

    programs = {
      nushell = {
        enable = lib.mkDefault true;
        plugins = with pkgs.nushellPlugins; [
          # dbus
          # skim
          # polars
          # semver
          # formats
          # highlight
          # desktop_notifications
        ];
        environmentVariables = {
          CLAP_PATH = lib.mkDefault "~/.nix-profile/lib/clap";
          DOTFILES_WALLPAPER_DIR = lib.mkDefault config.dotfiles.paths.wallpaperDirectory;
          LIBSQLITE = lib.mkDefault cfg.sqliteLibrary;
          WALLPAPER_DIR = lib.mkDefault config.dotfiles.paths.wallpaperDirectory;
        }
        // lib.optionalAttrs (config.home.sessionVariables ? EDITOR) {
          EDITOR = lib.mkDefault config.home.sessionVariables.EDITOR;
        }
        // lib.optionalAttrs (config.home.sessionVariables ? VISUAL) {
          VISUAL = lib.mkDefault config.home.sessionVariables.VISUAL;
        };
        # TODO: nushellのcompletion設定最適化とnixとの責務境界の確定
        settings = {
          completions = {
            case_sensitive = false;
            quick = true;
            partial = true;
            algorithm = "fuzzy";
            external = {
              enable = true;
              max_results = 200;
            };
          };
          footer_mode = "always";
        };
        extraConfig = nativeCompletionConfig;
        configFile.source = ./config/config.nu;
      };
    };
  };
}
