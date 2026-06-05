function sn
    sk -m --ansi -ic 'rg --line-number --glob !.git/ "{}"' | sd '(.*):(\d*):.*' '+$2 $1' | xargs nvim
end
