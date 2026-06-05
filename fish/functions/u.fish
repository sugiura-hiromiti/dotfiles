function u
    set dotfiles_nix "$HOME/dotfiles/nix"
    if not test -d "$dotfiles_nix"
        set dotfiles_nix "$HOME/.config/nix"
    end

    pushd "$dotfiles_nix" >/dev/null; or return 1

    nix run .#update -- $argv
    set update_status $status
    popd >/dev/null
    return $update_status
end
