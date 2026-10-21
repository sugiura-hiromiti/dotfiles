{
  reaperActions,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.dotfiles.programs.reaper.enable {
    programs = {
      reaper = {
        actions = {
          keyBindings = [ ];
          scripts = [
            {
              path = "which-key/leader.lua";
              source = ./which-key/leader.lua;
              section = reaperActions.sections.main;
              commandId = "RS_which_key_main";
            }
            {
              path = "which-key/leader.lua";
              section = reaperActions.sections.mdiEditor;
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
