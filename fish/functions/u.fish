function u
    pushd "$HOME/.config/nix" >/dev/null
    # build secret.nix content (note fish command substitutions)
    set who (whoami)
    set theme dark
    set hour (date +%H)
    if test $hour -gt 13 -a $hour -lt 15
        set theme light
    end

    set has_gui false
    if type -q dconf
        set has_gui true
    end

    printf "{}:\n{\n  user = \"%s\";\n  theme = \"%s\";\n  has_gui = %s;\n}\n" $who $theme $has_gui >secret.nix
    nix run .#update
    popd >/dev/null
end
