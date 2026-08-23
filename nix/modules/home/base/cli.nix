{ lib, ... }:
let
  cliPrograms = [
    "aria2"
    "bottom"
    "carapace"
    "cargo"
    "direnv"
    "emacs"
    "eza"
    "fd"
    "fish"
    "fzf"
    "gh"
    "git"
    "jujutsu"
    "nh"
    "nushell"
    "nvim"
    "ripgrep"
    "ssh"
    "starship"
    "translate-shell"
    "yazi"
    "zoxide"
  ];
in
{
  dotfiles = {
    programs = lib.genAttrs cliPrograms (_: {
      enable = lib.mkDefault true;
    });
  };
}
