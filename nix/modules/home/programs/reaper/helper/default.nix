{ lib, reaperActions }:
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
  inherit shortcutSetToList;
}
