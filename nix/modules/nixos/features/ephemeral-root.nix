{ lib, ... }: {
  options = {
    dotfiles = {
      features = {
        ephemeralRoot = {
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
