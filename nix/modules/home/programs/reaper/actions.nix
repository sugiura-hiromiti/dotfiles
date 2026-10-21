{
  config,
  lib,
  reaperActions,
  ...
}:

let
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
            main = {
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
            };
          };
        };
      };
    };
  };
}
