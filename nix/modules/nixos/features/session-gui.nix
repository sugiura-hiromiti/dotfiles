{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.sessionGui;
in
{
  options.dotfiles.features.sessionGui = {
    enable = lib.mkEnableOption "graphical session system integration";

    greeter = {
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

      command = lib.mkOption {
        type = lib.types.str;
        default = ''
          ${pkgs.tuigreet}/bin/tuigreet \
          --remember \
          --cmd ${pkgs.niri}/bin/niri-session
        '';
        defaultText = lib.literalExpression ''
          '''
            ''${pkgs.tuigreet}/bin/tuigreet \
            --remember \
            --cmd ''${pkgs.niri}/bin/niri-session
          '''
        '';
        description = "greetd default session command.";
      };
    };

    niri.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the Niri compositor module.";
    };

    xwayland.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
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

        services.greetd = {
          enable = true;
          useTextGreeter = true;
          settings.default_session = {
            command = cfg.greeter.command;
            user = cfg.greeter.user;
          };
        };

        programs = {
          xwayland.enable = cfg.xwayland.enable;
          niri = lib.mkIf cfg.niri.enable {
            enable = true;
            useNautilus = false;
          };
        };

        environment.systemPackages = [
          cfg.greeter.package
        ];
      }

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
