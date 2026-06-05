{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.geonkick;
  format = pkgs.formats.json { };
  presetsPath = "${config.home.homeDirectory}/.local/share/geonkick/presets";
in
{
  options.dotfiles.programs.geonkick = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to install the repository-managed Geonkick configuration.";
    };

    settings = lib.mkOption {
      inherit (format) type;
      default = {
        scaleFactor = 1.5;
        midiChannel = -1;
        midiChannelForced = false;
        showSidebar = true;
        bookmarkedPaths = [
          {
            name = "Presets Folders";
            paths = [ presetsPath ];
          }
        ];
        presetCurrentPath = "/";
        sampleCurrentPath = presetsPath;
        exportFormat = "flac24";
        exportNumberOfChannels = 1;
        bezierMode = false;
      };
      description = "Settings written to geonkick/config.json.";
    };
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    xdg.configFile."geonkick/config.json".source = format.generate "geonkick-config.json" cfg.settings;
  };
}
