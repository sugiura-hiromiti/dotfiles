function rw --description 'randomly choose wallpaper'
    set files (eza -f $WALLPAPER_DIR)
    set cnt (count $files)

    if test $cnt -eq 0
        echo "no files in this directory"
    else
        set idx (random 1 (count $files))
        set chosen $WALLPAPER_DIR/$files[$idx]
        echo $chosen | xargs awww img
        # viu $chosen
        # viu ~/Downloads/'Konachan.com - 76594 hatsune_miku kagamine_rin twintails vocaloid.jpg'
    end

end
