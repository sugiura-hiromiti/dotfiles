{ lib, ... }:
let
  programs = [
    # "alacritty"
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
    # "ghostty"
    "git"
    "jujutsu"
    # "kitty"
    "lazygit"
    "nh"
    "nushell"
    "nvim"
    "ripgrep"
    "ssh"
    "starship"
    "translate-shell"
    # "wezterm"
    "yazi"
    "zoxide"
  ];
in
{
  dotfiles = {
    programs = lib.genAttrs programs (_: {
      enable = lib.mkDefault true;
    });
  };
}
