{ lib, ... }:
{
  dotfiles.programs.prismlauncher.preserveData = lib.mkDefault true;
}
