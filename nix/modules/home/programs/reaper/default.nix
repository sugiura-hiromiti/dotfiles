{
  config,
  lib,
  reaperAppearance,
  ...
}:
let
  cfg = config.dotfiles.programs.reaper;
in
{
  imports = [
    ./lua-lsp.nix
    ./actions.nix
    ./which-key.nix
    ./smooth6.nix
  ];
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
          appearance = {
            zoomScrollOffset = {
              horizontalZoomCenter = reaperAppearance.zoomScrollOffset.zoomCenter.horizontal.editCursor;
            };
          };
          editingBehavior = {
            midiEditor = {
              oneMidiEditorPer = "project";
              behaviorForOpenItemsInBuiltInMidiEditor = "openAllMidiInTheProject";
              makeAllMidiItemsEditableByDefaultIfTheyAreVisibleInTheEditor = false;
              whenUsingOneMidiEditorPerProject = {
                activeMidiItemFollowsSelectionChangesInArrangeView = {
                  enable = true;
                  type = "mediaItem";
                };
                selectionIsLinkedToEditability = true;
              };
            };
          };
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
