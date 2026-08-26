{ lib, ... }:
let
  cliPrograms = [
    # NOTE: こいつらはnoctaliaの依存だった気がする
    "translate-shell"
    "aria2"

    "bottom"
    "carapace"
    "cargo"
    "direnv"
    "emacs"
    # NOTE: nushellでは使ってないので消すか？
    "eza"
    "fd"
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
