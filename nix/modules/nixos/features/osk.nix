{
  config,
  lib,
  pkgs,
  virtualKeyboardAdapter,
  ...
}:
let
  cfg = config.dotfiles.features.osk;
  controlCommand = "${pkgs.systemd}/bin/systemctl --user kill --kill-whom=main";
  autoShow = pkgs.writeShellApplication {
    name = "osk-auto-show";
    text = ''
      # Match properties within one device record; built-in keyboards do not suppress OSK.
      if ${pkgs.systemd}/bin/udevadm info --export-db --subsystem-match=input --no-pager |
        ${pkgs.gawk}/bin/awk '
          BEGIN { RS = "" }
          /(^|\n)E: ID_INPUT_KEYBOARD=1(\n|$)/ &&
          /(^|\n)E: ID_BUS=(usb|bluetooth)(\n|$)/ &&
          !/(^|\n)E: ID_INTEGRATION=internal(\n|$)/ { found = 1 }
          END { exit !found }
        '; then
        exit 0
      fi

      # Keep OSK available if the device query fails.
      exec ${controlCommand} --signal=SIGUSR2 wvkbd.service
    '';
  };
  focusAdapter = virtualKeyboardAdapter.overrideAttrs (old: {
    # Visibility follows text input focus, independently of the selected input method.
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/VirtualKeyboardAdapter.hpp \
        --replace-fail 'EventType::InputContextInputMethodActivated' 'EventType::InputContextFocusIn' \
        --replace-fail 'EventType::InputContextInputMethodDeactivated' 'EventType::InputContextFocusOut'
    '';
  });
in
{
  options = {
    dotfiles = {
      features = {
        osk = {
          enable = lib.mkEnableOption "fcitx5 on-screen keyboard integration";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    i18n = {
      inputMethod = {
        fcitx5 = {
          addons = [ focusAdapter ];
          settings = {
            addons = {
              virtualkeyboardadapter = {
                globalSection = {
                  ActivateCmd = ''"${lib.getExe autoShow}"'';
                  DeactivateCmd = ''"${controlCommand} --signal=SIGUSR1 wvkbd.service"'';
                };
              };
            };
          };
        };
      };
    };
  };
}
