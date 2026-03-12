function __fzl_cliphist --description 'select from clipboard history'
    cliphist list | fuzzel -d --prompt "Clipboard " | cliphist decode | wl-copy
end
