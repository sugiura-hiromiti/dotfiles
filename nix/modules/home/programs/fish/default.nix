{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.fish;
  completionFiles = lib.attrNames (
    lib.filterAttrs (_: type: type == "regular") (builtins.readDir ./config/completions)
  );
  completionConfigFiles = lib.listToAttrs (
    map (name: {
      name = "fish/completions/${name}";
      value.source = ./config/completions + "/${name}";
    }) completionFiles
  );
in
{
  options.dotfiles.programs.fish.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to install the repository-managed Fish configuration.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile = {
      "fish/config.fish".source = ./config/config.fish;
      "fish/conf.d" = {
        source = ./config/conf.d;
        recursive = true;
      };
      "fish/functions" = {
        source = ./config/functions;
        recursive = true;
      };
    }
    // completionConfigFiles;
  };
}
