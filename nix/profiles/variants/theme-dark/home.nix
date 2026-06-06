{
  lib,
  ...
}:
{
  dotfiles.features.theme.enable = lib.mkDefault true;
  catppuccin.flavor = "frappe";
}
