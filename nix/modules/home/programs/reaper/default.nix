{
  pkgs,
  config,
  lib,
  reaperFlake,
  ...
}:
let
  cfg = config.dotfiles.programs.reaper;
in
{
  options = {
    dotfiles = {
      programs = {
        reaper = {
          enable = lib.mkEnableOption "repository-managed REAPER configuration";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      reaper = {
        enable = true;
        theme = {
          packages = [ reaperFlake.packages.${pkgs.system}.smooth6-theme ];
          active = "Smooth_6.ReaperThemeZip";
        };
        extensions = {
          sws = {
            enable = true;
          };
          reapack = {
            enable = true;
            synchronizeOnActivation = true;
            installNewPackagesWhenSynchronizing = false;
            repositories = [ ];
          };
        };
        preferences = {
          project = {
            backups = {
              autoSave = {
                autoSaveUnsavedProjectsToTemporaryFile = true;
                autoSaveInterval = {
                  minutes = 5;
                  mode = "whenNotRecording";
                };
                autoSaveToTimestampedFileInProjectDirectory = {
                  enable = true;
                  saveAutoSavedProjectBackupsToAutoSavesProjectSubdirectory = true;
                  limitAutoSavedBackupsToMostRecent = {
                    enable = true;
                    count = 30;
                    unit = "copies";
                  };
                };
              };
              whenSaving = {
                preservePreviouslySavedVersionsOfProjectAsProjectTimestampRppBak = {
                  enable = true;
                  saveTimestampedBackupsToBackupsProjectSubdirectory = true;
                  limitBackupsToMostRecent = {
                    enable = true;
                    count = 30;
                    unit = "copies";
                  };
                };
              };
            };
            promptToSaveOnNewProject = true;
            projectSaving = {
              saveFileReferencesWithRelativePathnames = true;
            };
          };
          general = {
            paths = {
              defaultProjectSavePath = "${config.dotfiles.paths.workspaceRoot}/reaper";
            };

            startupSettings = {
              showSplashScreenOnStartup = false;
            };
          };
        };
      };
    };
  };
}
