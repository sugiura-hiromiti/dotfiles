{
  config,
  lib,
  reaperActions,
  ...
}:

let
  scrollBindings = {
    "Ctrl+H" = {
      command = 40140;
      actionName = "Scroll left";
    };
    "Ctrl+J" = {
      command = 40139;
      actionName = "Scroll down";
    };
    "Ctrl+K" = {
      command = 40138;
      actionName = "Scroll up";
    };
    "Ctrl+L" = {
      command = 40141;
      actionName = "Scroll right";
    };
  };
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
              H = {
                command = 40414;
                actionName = "Select previous note";
              };
              L = {
                command = 40413;
                actionName = "Select next note";
              };
              J = {
                command = 41765;
                actionName = "Select next note with lower pitch";
              };
              K = {
                command = 41764;
                actionName = "Select next note with higher pitch";
              };
              S = {
                command = 40046;
                actionName = "Split notes at edit cursor";
              };
              "Shift+H" = {
                command = 40183;
                actionName = "Move notes left one grid unit";
              };
              "Shift+L" = {
                command = 40184;
                actionName = "Move notes right one grid unit";
              };
              "Shift+J" = {
                command = 40178;
                actionName = "Move notes down one semitone";
              };
              "Shift+K" = {
                command = 40177;
                actionName = "Move notes up one semitone";
              };
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
            // zoomBindings
            // scrollBindings;
            main = {
              S = {
                command = 40757;
                actionName = "split items at edit cursor";
              };
              "Shift+H" = {
                command = 40793;
                actionName = "Move items left by grid";
              };
              "Shift+L" = {
                command = 40794;
                actionName = "Move items right by grid";
              };
              "Shift+J" = {
                command = 40118;
                actionName = "Move items down one track";
              };
              "Shift+K" = {
                command = 40117;
                actionName = "Move items up one track";
              };
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
              F = {
                command = 40069;
                actionName = "jump to time/marker/region";
              };
            }
            // zoomBindings
            // scrollBindings;
          };
        };
      };
    };
  };
}
