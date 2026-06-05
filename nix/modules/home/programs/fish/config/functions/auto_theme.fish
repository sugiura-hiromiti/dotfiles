function auto_theme --description 'determines system appearance light or dark'
    set hour (date +%H)
    if test $hour -gt 6 -a $hour -lt 18
        sa_light
    else
        sa_dark
    end
end
