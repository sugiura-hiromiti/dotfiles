{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.darwin.homebrew;
in
{
  options.dotfiles.darwin.homebrew = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to configure Homebrew packages.";
    };

    brews = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [ ];
      description = "Homebrew formulae to install.";
    };

    casks = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [ ];
      description = "Homebrew casks to install.";
    };

    taps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Homebrew taps to configure.";
    };

    masApps = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = { };
      description = "Mac App Store applications to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    homebrew = {
      enable = lib.mkDefault true;

      onActivation = {
        autoUpdate = lib.mkDefault true;
        upgrade = lib.mkDefault true;
        cleanup = lib.mkDefault "zap";
      };

      inherit (cfg)
        brews
        casks
        taps
        masApps
        ;
    };
  };
}
