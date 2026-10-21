{
  accounts,
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.prismlauncher;
in
{
  options = {
    dotfiles = {
      programs = {
        prismlauncher = {
          preserveData = lib.mkEnableOption "persistent PrismLauncher data";
        };
      };
    };
  };
  config = lib.mkIf (cfg.preserveData && config.dotfiles.features.preservation.enable) {
    preservation = {
      preserveAt = {
        "/persist" = {
          users = {
            ${accounts.primary} = {
              directories = [ ".local/share/PrismLauncher" ];
            };
          };
        };
      };
    };
  };
}
