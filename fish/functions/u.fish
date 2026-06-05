function u
    set dotfiles_nix "$HOME/dotfiles/nix"
    if not test -d "$dotfiles_nix"
        set dotfiles_nix "$HOME/.config/nix"
    end

    pushd "$dotfiles_nix" >/dev/null; or return 1

    set theme dark
    set hour (date +%H)
    set hour (math $hour)
    if test $hour -gt 5; and test $hour -lt 17
        set theme light
    end

    set session tty
    if set -q WAYLAND_DISPLAY; and test -n "$WAYLAND_DISPLAY"
        set session gui
    else if set -q DISPLAY; and test -n "$DISPLAY"
        set session gui
    end

    sudo -v
    nix run .#update -- --theme $theme --session $session
    popd >/dev/null
end
