{ config, lib, ... }: {
  config = lib.mkIf config.dotfiles.programs.reaper.enable {
    programs = {
      reaper = {
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
