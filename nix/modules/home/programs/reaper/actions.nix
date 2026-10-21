{
  config,
  lib,
  reaperActions,
  ...
}:

let

  zoomBindings = {
    minus = {
      command = 1011;
      actionName = "Zoom out horizontally";
    };
    equals = {
      command = 1012;
      actionName = "Zoom in horizontally";
    };
    "Shift+minus" = {
      command = 40112;
      actionName = "Zoom out vertically";
    };
    "Shift+equals" = {
      command = 40111;
      actionName = "Zoom in vertically";
    };
  };
  shortcutSetToList =
    sections:
    lib.concatLists (
      lib.mapAttrsToList (
        sectionName: shortcuts:
        lib.mapAttrsToList (
          shortcut: value:
          reaperActions.shortcut (
            value
            // {
              inherit shortcut;
              section = reaperActions.sections.${sectionName};
            }
          )
        ) shortcuts
      ) sections
    );
in
{
  config = lib.mkIf config.dotfiles.programs.reaper.enable {
    programs = {
      reaper = {
        actions = {
          keyBindings = shortcutSetToList {
            midiEditor = {
              Left = {
                command = 40047;
                actionName = "Move cursor left by grid";
              };
              Right = {
                command = 40048;
                actionName = "Move cursor right by grid";
              };
              Down = {
                command = 40212;
                actionName = "Halve grid size";
              };
              Up = {
                command = 40210;
                actionName = "Double grid size";
              };
            }
            // zoomBindings;
            main = {
              Left = {
                command = 40646;
                actionName = "move cursor left to grid";
              };
              Right = {
                command = 40647;
                actionName = "move cursor right to grid";
              };
              Up = {
                command = 40786;
                actionName = "double grid size";
              };
              Down = {
                command = 40783;
                actionName = "halve grid size";
              };
              H = {
                command = 40416;
                actionName = "Select previous item";
              };
              L = {
                command = 40417;
                actionName = "Select next item";
              };
              K = {
                command = 40286;
                actionName = "Previous track";
              };
              J = {
                command = 40285;
                actionName = "Next track";
              };
              "/" = {
                command = 40069;
                actionName = "jump to time/marker/region";
              };
              "Ctrl+J" = {
                command = 0;
                actionName = "Unbind default jump shortcut";
              };
            }
            // zoomBindings;
          };
        };
      };
    };
  };
}
