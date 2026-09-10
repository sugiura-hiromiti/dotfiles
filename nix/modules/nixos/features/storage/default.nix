{ lib, ... }: {
  options = {
    dotfiles = {
      storage = {
        device = lib.mkOption { type = lib.types.str; };
        subvolumes = {
          root = lib.mkOption {
            type = lib.types.str;
            default = "@root";
          };
          persist = lib.mkOption {
            type = lib.types.str;
            default = "@persist";
          };
          nix = lib.mkOption {
            type = lib.types.str;
            default = "@nix";
          };

        };
      };
    };
  };
}
