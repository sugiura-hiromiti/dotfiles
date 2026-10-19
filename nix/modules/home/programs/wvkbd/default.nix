{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.wvkbd;
in
{
  options = {
    dotfiles = {
      programs = {
        wvkbd = {
          enable = lib.mkEnableOption "wvkbd on-screen keyboard";
          toggleCommand = lib.mkOption {
            type = lib.types.str;
            readOnly = true;
            default =
              "${pkgs.systemd}/bin/systemctl --user kill " + "--kill-whom-main --signal-SIGRTMIN wvkbd.service";
            description = "Command to toggle wvkbd visibility.";
          };
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    home = {
      packages = [ pkgs.wvkbd ];
    };
    systemd = {
      user = {
        services = {
          wvkbd = {
            Unit = {
              Description = "Wayland virtual keyboard";
              PartOf = [ "graphical-session.target" ];
              After = [ "graphical-session.target" ];
            };
            Service = {
              ExecStart = "${pkgs.wvkbd}/bin/wvkbd-mobintl --hidden";
              Restart = "on-failure";
            };
            Install = {
              WantedBy = [ "graphical-session.target" ];
            };
          };
        };
      };
    };
  };
}
