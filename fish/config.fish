if status is-interactive
    # Commands to run in interactive sessions can go here
    # set ZELLIJ_AUTO_ATTACH true
    # set ZELLIJ_AUTO_EXIT true
    # eval (zellij setup --generate-auto-start fish | string collect)
end

set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx MANPAGER less
set -gx RIPGREP_CONFIG_PATH "$HOME/.config/rg/config"
set -gx MY_CUSTOM_ENV_VARS_CURRENTLY_EXECUTING_PROMPT ""
set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx XDG_CACHE_HOME "$HOME/.cache"
set -gx WALLPAPER_DIR "$HOME/Downloads/wallpapers"

cat "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" | babelfish | source

fish_add_path $HOME/.nix-profile/bin
fish_add_path /nix/var/nix/profiles/default/bin
fish_add_path $HOME/.config/bin
fish_add_path $HOME/.cargo/bin

abbr -a ga --set-cursor "git stage . && git commit -m '%' && git push"
abbr -a bi --set-cursor "lsappinfo info -only bundleid \"%\""
abbr -a c "sudo nix-collect-garbage -d ; sudo nix-store --optimise ; sudo nix-store --gc ; nix profile wipe-history ; sudo rm -rf ~/.cache/nix/"
abbr -a drv_shw --set-cursor "nix derivation show nixpkgs#% | jq 'to_entries | .[0].value.outputs.out.path'"

starship init fish | source
direnv hook fish | source
zoxide init fish | source
