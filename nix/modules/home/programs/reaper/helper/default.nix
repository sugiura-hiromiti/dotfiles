{ lib, reaperActions }:
let
  arrowKeyCodes = {
    Left = 32805;
    Up = 32806;
    Right = 32807;
    Down = 32808;
  };
  shortcutSetToList =
    sections:
    lib.concatLists (
      lib.mapAttrsToList (
        sectionName: shortcuts:
        lib.mapAttrsToList (
          shortcut: value:
          let
            key = lib.last (lib.splitString "+" shortcut);
            binding = reaperActions.shortcut (
              value
              // {
                inherit shortcut;
                section = reaperActions.sections.${sectionName};
              }
            );
          in
          if builtins.hasAttr key arrowKeyCodes then
            binding // { keyCode = arrowKeyCodes.${key}; }
          else
            binding
        ) shortcuts
      ) sections
    );
in
{
  inherit shortcutSetToList;
}
