{ lib, ... }:
{
  dotfiles.features.terminal.enable = lib.mkDefault true;

  dotfiles.programs = {
    alacritty.enable = lib.mkDefault true;
    aria2.enable = lib.mkDefault true;
    bottom.enable = lib.mkDefault true;
    carapace.enable = lib.mkDefault true;
    cargo.enable = lib.mkDefault true;
    direnv.enable = lib.mkDefault true;
    emacs.enable = lib.mkDefault true;
    eza.enable = lib.mkDefault true;
    fd.enable = lib.mkDefault true;
    fish.enable = lib.mkDefault true;
    fzf.enable = lib.mkDefault true;
    gh.enable = lib.mkDefault true;
    ghostty.enable = lib.mkDefault true;
    git.enable = lib.mkDefault true;
    jujutsu.enable = lib.mkDefault true;
    kitty.enable = lib.mkDefault true;
    lazygit.enable = lib.mkDefault true;
    nh.enable = lib.mkDefault true;
    nushell.enable = lib.mkDefault true;
    nvim.enable = lib.mkDefault true;
    ripgrep.enable = lib.mkDefault true;
    ssh.enable = lib.mkDefault true;
    starship.enable = lib.mkDefault true;
    translate-shell.enable = lib.mkDefault true;
    wezterm.enable = lib.mkDefault true;
    yazi.enable = lib.mkDefault true;
    zoxide.enable = lib.mkDefault true;
  };
}
