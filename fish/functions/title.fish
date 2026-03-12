function title
    if test (count $argv) -gt 0
        printf "\033]0;%s\007" "$argv"
        if test (uname) = "Darwin"
            # preserve your external hook if you have it
            command -sq external_1; and external_1 --trigger zsh_title TITLE="$argv"
        end
    end
end
