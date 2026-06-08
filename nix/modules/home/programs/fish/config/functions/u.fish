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

    set -l nix_access_token_override "access-tokens ="
    if set -q NIX_CONFIG; and test -n "$NIX_CONFIG"
        set -lx NIX_CONFIG (string join \n -- "$NIX_CONFIG" "$nix_access_token_override")
    else
        set -lx NIX_CONFIG "$nix_access_token_override"
    end

    nix run path:.#update -- $argv
    set update_status $status
    popd >/dev/null
    return $update_status
end
