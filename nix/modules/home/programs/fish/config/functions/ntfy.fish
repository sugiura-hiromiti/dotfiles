function ntfy
    # wezterm/kitty-compatible notify escape
    printf "\033]777;notify;%s;%s\007" "$argv[1]" "$argv[2]"
end
