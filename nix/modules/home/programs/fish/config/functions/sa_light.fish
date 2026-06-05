function sa_light --description 'set desktop appearance config to "prefer-light"'
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
end
