{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.nushell;
  sqliteLibrary = "${pkgs.sqlite.out}/lib/${
    if pkgs.stdenv.isDarwin then "libsqlite3.dylib" else "libsqlite3.so"
  }";
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
        "''${pkgs.sqlite.out}/lib/''${if pkgs.stdenv.isDarwin then "libsqlite3.dylib" else "libsqlite3.so"}"
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
      file = lib.mkIf pkgs.stdenv.isDarwin {
        "nushell_appsupport_config" = {
          target = "Library/Application Support/nushell/config.nu";
          source = ./config/config.nu;
        };
      };
    };

    programs.nushell = {
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
        LIBSQLITE = lib.mkDefault cfg.sqliteLibrary;
      };
      configFile.source = ./config/config.nu;
    };
  };
}
