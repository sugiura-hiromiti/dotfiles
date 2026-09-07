{ lib, ... }: {
  options = {
    dotfiles = {
      features = {
        ephemeralRoot = {
          device = lib.mkOption {
            type = lib.types.str;
            description = "btrfs device containing the ephemeral @root subvolume";
          };
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "whether to enable ephemeral root for impermanent system";
          };
        };
      };
    };
  };
  config = { };
}
