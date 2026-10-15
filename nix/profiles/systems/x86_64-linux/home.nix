{ lib, ... }: {
  dotfiles = {
    features = {
      sessionGui = {
        fcitx5 = {
          packages = lib.mkForce [ ];
        };
      };
    };
  };
}
