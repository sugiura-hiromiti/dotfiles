complete -c xremap -l device -d 'Include a device name or path' -r
complete -c xremap -l ignore -d 'Ignore a device name or path' -r
complete -c xremap -l watch -d 'Targets to watch' -r -f -a "{device	add new devices automatically,config	reload the config automatically}"
complete -c xremap -l completions -d 'Generate shell completions' -r -f -a "{bash	,elvish	,fish	,powershell	,zsh	}"
complete -c xremap -l output-device-name -r
complete -c xremap -l vendor -r
complete -c xremap -l product -r
complete -c xremap -l mouse -d 'Match mice by default'
complete -c xremap -s h -l help -d 'Print help (see more with \'--help\')'
complete -c xremap -s V -l version -d 'Print version'
