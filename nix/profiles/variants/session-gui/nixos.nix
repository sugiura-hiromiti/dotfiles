{ lib, pkgs, ... }:
{
  services = {
    greetd = {
      enable = true;
      useTextGreeter = true;
      settings = {
        default_session = {
          command = ''
            ${pkgs.tuigreet}/bin/tuigreet \
            --remember \
            --cmd ${pkgs.niri}/bin/niri-session
          '';
          user = "greeter";
        };
      };
    };
  };

  programs = {
    xwayland.enable = true;
    niri = {
      enable = true;
      # package = pkgs.niri-unstable;
      useNautilus = false;
    };
  };

  environment.systemPackages = with pkgs; [
    tuigreet
  ];

  specialisation.no-gui.configuration = {
    system.nixos.tags = [ "no-gui" ];
    systemd.defaultUnit = lib.mkForce "multi-user.target";
    services.greetd.enable = lib.mkForce false;
    programs.xwayland.enable = lib.mkForce false;
  };
}
