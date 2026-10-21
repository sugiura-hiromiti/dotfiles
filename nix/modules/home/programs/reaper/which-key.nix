{
  reaperActions,
  config,
  lib,
  ...
}:
let
  helper = import ./helper { inherit lib reaperActions; };
  inherit (helper) shortcutSetToList;

in
{
  config = lib.mkIf config.dotfiles.programs.reaper.enable {
    programs = {
      reaper = {
        actions = {
          keyBindings = shortcutSetToList {
            main = {
              "/" = {
                command = "RS_which_key_main";
                actionName = "open command palette";
              };
            };
            midiEditor = {
              "/" = {
                command = "RS_which_key_midi";
                actionName = "open midi command palette";
              };
            };
          };
          scripts = [
            {
              path = "which-key/leader.lua";
              source = ./which-key/leader.lua;
              section = reaperActions.sections.main;
              commandId = "RS_which_key_main";
            }
            {
              path = "which-key/leader.lua";
              section = reaperActions.sections.midiEditor;
              commandId = "RS_which_key_midi";
            }
          ];
        };
        extensions = {
          reapack = {
            repositories = [
              {
                name = "Souk21 ReaPack";
                url = "https://raw.githubusercontent.com/Souk21/REAPER-scripts-and-effects/master/index.xml";
                installNewPackages = "manual";
              }
            ];
            packages = [
              {
                repository = "Souk21 ReaPack";
                category = "Scripts";
                name = "Key Sequences.lua";
              }
              {
                repository = "ReaTeam Extensions";
                category = "API";
                name = "js_ReaScriptAPI.ext";
              }
              {
                repository = "ReaTeam Extensions";
                category = "API";
                name = "reaper_imgui.ext";
              }
            ];
          };
        };
      };
    };
  };
}
