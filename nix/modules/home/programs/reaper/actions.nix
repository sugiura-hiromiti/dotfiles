{
  config,
  lib,
  reaperActions,
  ...
}:
let
  shortcutSetToList =
    shortcutSet:
    lib.mapAttrsToList (
      name: value: (reaperActions.shortcut (value // { shortcut = name; }))
    ) shortcutSet;
in
{
  config = lib.mkIf config.dotfiles.programs.reaper.enable {
    programs = {
      reaper = {
        actions = {
          keyBindings = shortcutSetToList {
            L = {
              command = 40416;
              actionName = "Select previous item";
            };
            H = {
              command = 40417;
              actionname = "Select next item";
            };
            K = {
              command = 40286;
              actionName = "Previous track";
            };
            J = {
              command = 40285;
              actionName = "Next track";
            };
          };
        };
      };
    };
  };
}
