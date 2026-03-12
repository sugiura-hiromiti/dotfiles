function s --wraps='eza -ahlF --icons --group-directories-first --sort=extension --time-style=iso --git' --description 'alias s=…'
    eza -ahlF --icons --group-directories-first --sort=extension --time-style=iso --git $argv
end
