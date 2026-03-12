function sa_dark --description 'set desktop appearance config to "prefer-dark"'
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
end
