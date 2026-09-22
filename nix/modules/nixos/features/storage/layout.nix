{
  partitionLabel = "dotfiles-system";
  installerDisk = "/dev/dotfiles-install-target";
  subvolumes = {
    root = "@root";
    nix = "@nix";
    persist = "@persist";
  };
}
