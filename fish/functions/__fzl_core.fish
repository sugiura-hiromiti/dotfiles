function __fzl_core --description 'fuzzel center'
    set cmd (printf "Apps\nClipboard\nWindows\nPower\n" | fuzzel -d)
    switch $cmd
        case Apps
            fuzzel
        case Clipboard
            __fzl_cliphist
        case Power
            __fzl_power
    end
end
