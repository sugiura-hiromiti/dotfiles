{
  accounts,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.sessionGui;
  greeterCommand = lib.escapeShellArgs [
    (lib.getExe cfg.greeter.package)
    "--remember"
    "--cmd"
    cfg.greeter.sessionCommand
  ];
in
{
  options.dotfiles.features.sessionGui = {
    enable = lib.mkEnableOption "graphical session system integration";

    greeter = {
      backend = lib.mkOption {
        type = lib.types.enum [
          "tuigreet"
          "noctalia"
        ];
        default = "noctalia";
        description = "greeter implementation";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.tuigreet;
        defaultText = lib.literalExpression "pkgs.tuigreet";
        description = "Text greeter package used by greetd.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "greeter";
        description = "User that runs the greetd default session.";
      };

      sessionCommand = lib.mkOption {
        type = lib.types.str;
        default = lib.getExe' pkgs.niri "niri-session";
        defaultText = lib.literalExpression ''lib.getExe' pkgs.niri "niri-session"'';
        description = "Graphical session command launched by the greeter";
      };
    };

    niri.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the Niri compositor module.";
    };

    xwayland.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable Xwayland support.";
    };

    noGuiSpecialisation.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to add a no-gui NixOS specialisation.";
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
        ];

        services = {
          accounts-daemon = {
            enable = true;
          };
          greetd = {
            enable = true;
            useTextGreeter = true;
            settings = {
              default_session = {
                command = greeterCommand;
                user = cfg.greeter.user;
              };
            };
          };
        };

        programs = {
          xwayland.enable = cfg.xwayland.enable;
          niri = lib.mkIf cfg.niri.enable {
            enable = true;
            useNautilus = false;
          };
        };

      }

      (lib.mkIf (cfg.greeter.backend == "tuigreet") {
        environment.systemPackages = [
          cfg.greeter.package
        ];
        services = {
          greetd = {
            enable = true;
            useTextGreeter = true;
            settings = {
              default_session = {
                command = greeterCommand;
                user = cfg.greeter.user;
              };
            };
          };
        };
      })

      (lib.mkIf (cfg.greeter.backend == "noctalia") {
        services = {
          displayManager = {
            noctalia-greeter = {
              passwordlessSyncUsers = [ accounts.primary ];
              enable = true;
              settings = {
                session = {
                  default = "niri";
                  keyboard = {
                    layout = "us";
                  };
                };
              };
            };
          };
        };
      })

      (lib.mkIf cfg.noGuiSpecialisation.enable {
        specialisation."no-gui".configuration = {
          system.nixos.tags = [ "no-gui" ];
          systemd.defaultUnit = lib.mkForce "multi-user.target";
          services.greetd.enable = lib.mkForce false;
          programs.xwayland.enable = lib.mkForce false;
        };
      })
    ]
  );
}
