{
  config,
  cfg,
  lib,
  terminalCommand,
  theme,
}:
{
  bar = {
    barType = "floating";
    position = "right";
    density = "spacious";
    fontScale = 1;
    floating = true;
    useSeparateOpacity = true;
    backgroundOpacity = 0.0;
    capsureOpacity = 0.85;
    marginVertical = 10;
    marginHorizontal = 10;
    displayMode = "auto_hide";
    autoHideDelay = 600;
    autoShowDelay = 0;
    widgets = {
      left = [
        { id = "Launcher"; }
        {
          id = "Workspace";
          showApplications = true;
        }
        { id = "SystemMonitor"; }
        {
          id = "ActiveWindow";
          colorizeIcons = true;
        }
        {
          id = "MediaMini";
          showVisualizer = cfg.visualizer.enable;
        }
      ];
      center = [
        {
          id = "Clock";
          formatVertical = "MM dd | HH mm";
          useMonospacedFont = true;
        }
      ];
      right = [
        { id = "NotificationHistory"; }
        {
          id = "Battery";
          alwaysShowPercentage = true;
          warningThreshold = 30;
        }
        {
          id = "Volume";
        }
      ]
      ++ lib.optionals cfg.ddc.enable [
        { id = "Brightness"; }
      ]
      ++ lib.optionals cfg.wallpaper.enable [
        { id = "WallpaperSelector"; }
      ]
      ++ lib.optionals cfg.screenToolkit.enable [
        { id = "plugin:screen-toolkit"; }
      ];
    };
  };
  general = {
    lockScreenAnimations = true;
    enableLockScreenMediaControls = true;
    enableBlurBehind = true;
    lockScreenBlur = 0.7;
    lockScreenTint = 0.3;
  };
  appLauncher = {
    enableClipboardHistory = cfg.clipboard.enable;
    autoPasteClipboard = cfg.clipboard.enable;
    inherit terminalCommand;
    showIconBackground = true;
    density = "comfortable";
  };
  network = {
    bluetoothRssiPollingEnabled = true;
  };
  notifications = {
    enableMarkdown = true;
    location = "bottom_left";
    backgroundOpacity = 0.3;
    saveToHistory = {
      low = false;
    };
    sounds = {
      enable = true;
      excludedApps = "";
      enableMediaToast = true;
    };
  };
  brightness = {
    enableDdcSupport = cfg.ddc.enable;
  };
  colorSchemes = {
    predefinedScheme = "Catppuccin";
    schedulingMode = "location";
    darkMode = theme == "dark";
  };
}
// lib.optionalAttrs cfg.wallpaper.enable {
  wallpaper = {
    directory = "${config.dotfiles.paths.wallpaperDirectory}/";
    overviewEnabled = true;
    automationEnabled = true;
    randomIntervalSec = 60;
    wallpaperChangeMode = "random";
    overviewBlur = 0.35;
    overviewTint = 0.5;
    useWallhaven = false;
    wallhavenSorting = "hot";
    wallhavenCategories = "110";
    wallhavenPurity = "010";
  };
}
