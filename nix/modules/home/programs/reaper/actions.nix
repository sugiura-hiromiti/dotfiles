{
  config,
  lib,
  reaperActions,
  ...
}:
let
  shortcutSetToList = { main, global }: mainShortcutSetToList main globalShortcutSetToList global;
  mainShortcutSetToList =
    shortcutSet:
    lib.mapAttrsToList (
      name: value: (reaperActions.shortcut (value // { shortcut = name; }))
    ) shortcutSet;
  mapShortcut =
    section: shortcutSet:
    lib.mapAttrsToList (
      name: value:
      (reaperActions.shortcut (
        value
        // {
          shortcut = name;
          sections = section;
        }
      ))
    ) shortcutSet;
in
{
  config = lib.mkIf config.dotfiles.programs.reaper.enable {
    programs = {
      reaper = {
        actions = {
          keyBindings = mainShortcutSetToList {
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
}
