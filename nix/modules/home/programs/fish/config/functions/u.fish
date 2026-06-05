function u
    set flake_root "$HOME/dotfiles"
    if not test -f "$flake_root/flake.nix"
        set flake_root "$HOME/dotfiles/nix"
    end
    if not test -f "$flake_root/flake.nix"
        set flake_root "$HOME/.config/nix"
    end
    if not test -f "$flake_root/flake.nix"
        echo "could not find dotfiles flake" >&2
        return 1
    end

    pushd "$flake_root" >/dev/null; or return 1

    nix run path:.#update -- $argv
    set update_status $status
    popd >/dev/null
    return $update_status
end
