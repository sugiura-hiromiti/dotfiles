{
  accounts,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.sessionGui;
  sessions.niri = {
    desktopName = "niri";
    command = lib.getExe' config.programs.niri.package "niri-session";
  };
  selectedSession = sessions.${cfg.session};
  greeterCommand = lib.escapeShellArgs [
    (lib.getExe cfg.greeter.tuigreet.package)
    "--remember"
    "--cmd"
    selectedSession.command
  ];
  noctalia = config.services.displayManager.noctalia-greeter;
  noctaliaCommand = "${lib.getExe' noctalia.package "noctalia-greeter-session"} ${lib.escapeShellArgs noctalia.extraArgs}";
in
{
  options.dotfiles.features.sessionGui = {
    enable = lib.mkEnableOption "graphical session system integration";

    session = lib.mkOption {
      type = lib.types.enum [ "niri" ];
      default = "niri";
      description = "Graphical session provided by this feature.";
    };

    greeter = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this feature requests a login greeter for the selected session.";
      };

      backend = lib.mkOption {
        type = lib.types.enum [
          "tuigreet"
          "noctalia"
        ];
        default = "noctalia";
        description = "Greeter implementation for the selected session.";
      };

      tuigreet = {
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.tuigreet;
          defaultText = lib.literalExpression "pkgs.tuigreet";
          description = "Text greeter package used by greetd.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "greeter";
          description = "User that runs the tuigreet default session.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = pkgs.stdenv.hostPlatform.isLinux;
            message = "dotfiles.features.sessionGui is Linux-only.";
          }
          {
            assertion =
              config.programs.niri.enable
              && lib.any (
                package:
                toString package == toString config.programs.niri.package
                && lib.elem selectedSession.desktopName package.providedSessions
              ) config.services.displayManager.sessionPackages;
            message = "dotfiles.features.sessionGui.session requires the selected Niri package and its niri session entry to remain enabled.";
          }
        ];

        programs.niri = {
          enable = true;
          useNautilus = false;
        };
      }

      (lib.mkIf (cfg.greeter.enable && cfg.greeter.backend == "tuigreet") {
        assertions = [
          {
            assertion = builtins.hasAttr cfg.greeter.tuigreet.user config.users.users;
            message = "dotfiles.features.sessionGui.greeter.tuigreet.user requires an existing users.users account.";
          }
          {
            assertion =
              config.services.greetd.enable
              && config.services.greetd.useTextGreeter
              && config.services.greetd.settings.default_session.command == greeterCommand
              && config.services.greetd.settings.default_session.user == cfg.greeter.tuigreet.user;
            message = "dotfiles.features.sessionGui.greeter requires greetd to run the selected tuigreet package, user, and session command.";
          }
        ];

        environment.systemPackages = [ cfg.greeter.tuigreet.package ];
        services.greetd = {
          enable = true;
          useTextGreeter = true;
          settings.default_session = {
            command = greeterCommand;
            user = cfg.greeter.tuigreet.user;
          };
        };
      })

      (lib.mkIf (cfg.greeter.enable && cfg.greeter.backend == "noctalia") {
        assertions = [
          {
            assertion =
              noctalia.enable
              && config.services.greetd.enable
              && config.services.displayManager.enable
              && config.services.greetd.settings.default_session.command == noctaliaCommand
              && noctalia.settings.session.default == selectedSession.desktopName;
            message = "dotfiles.features.sessionGui.greeter requires Noctalia and greetd to remain enabled with discovery of the selected session entry.";
          }
        ];

        services.displayManager.noctalia-greeter = {
          enable = true;
          passwordlessSyncUsers = [ accounts.primary ];
          settings = {
            session.default = selectedSession.desktopName;
            keyboard.layout = "us";
          };
        };
      })
    ]
  );
}
