function __fzl_power --description niri
    set action (printf "suspend\nshutdown\nreboot\n" | fuzzel -d --prompt "Power ")
    switch $action
        case suspend
            systemctl suspend
        case shutdown
            systemctl shutdown
        case reboot
            systemctl reboot
    end
end
