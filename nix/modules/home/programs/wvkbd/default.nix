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
