{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.prismlauncher;
in
{
  options.dotfiles.programs.prismlauncher.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "whether to install the repository-managed prismlauncher configuration.";

  };

  config = lib.mkIf cfg.enable {
    programs.prismlauncher = {
      enable = lib.mkDefault true;
    };
  };
}
