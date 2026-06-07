{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.paths;
in
{
  # dotfiles.paths is the home-layout contract. Host/profile modules may override
  # these options, while program modules should consume them instead of hard-coding
  # local directory rules.
  options.dotfiles.paths = {
    downloads = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Downloads";
      description = "Directory used as the base for personal downloads and local media.";
    };

    mediaDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.downloads}/media";
      description = "Directory used as the base for local media assets.";
    };

    workspaceRoot = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.downloads}/awa";
      description = "Root directory for local workspaces and cloned repositories.";
    };

    orgDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.workspaceRoot}/org";
      description = "Directory used by Org configuration.";
    };

    wallpaperDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.mediaDirectory}/wallpapers";
      description = "Directory containing local wallpaper assets.";
    };

    screenshotDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.mediaDirectory}/screenshots";
      description = "Directory where screenshot tools save captured images.";
    };
  };

  config.home.sessionVariables = {
    DOTFILES_DOWNLOADS = lib.mkDefault cfg.downloads;
    DOTFILES_MEDIA_DIR = lib.mkDefault cfg.mediaDirectory;
    DOTFILES_WORKSPACE_ROOT = lib.mkDefault cfg.workspaceRoot;
    DOTFILES_ORG_DIRECTORY = lib.mkDefault cfg.orgDirectory;
    DOTFILES_WALLPAPER_DIR = lib.mkDefault cfg.wallpaperDirectory;
    DOTFILES_SCREENSHOT_DIR = lib.mkDefault cfg.screenshotDirectory;
    WALLPAPER_DIR = lib.mkDefault cfg.wallpaperDirectory;
  };
}
