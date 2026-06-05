# Print an optspec for argparse to handle cmd's options that are independent of any subcommand.
function __fish_clipcatctl_global_optspecs
	string join \n c/config= server-endpoint= log-level= h/help V/version
end

function __fish_clipcatctl_needs_command
	# Figure out if the current invocation already has a command.
	set -l cmd (commandline -opc)
	set -e cmd[1]
	argparse -s (__fish_clipcatctl_global_optspecs) -- $cmd 2>/dev/null
	or return
	if set -q argv[1]
		# Also print the command, so this can be used to figure out what it is.
		echo $argv[1]
		return 1
	end
	return 0
end

function __fish_clipcatctl_using_subcommand
	set -l cmd (__fish_clipcatctl_needs_command)
	test -z "$cmd"
	and return 1
	contains -- $cmd[1] $argv
end

complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -s c -l config -d 'Specify a configuration file' -r -F
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -l server-endpoint -d 'Specify a server endpoint' -r
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -l log-level -d 'Specify a log level' -r
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -s V -l version -d 'Print version'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "version" -d 'Print the client and server version information'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "completions" -d 'Output shell completion code for the specified shell (bash, zsh, fish)'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "default-config" -d 'Output default configuration'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "insert" -d 'Insert new clip into clipboard'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "load" -d 'Loads file into clipboard'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "save" -d 'Paste content of current clipboard into file'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "get" -d 'Print clip with <id>'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "list" -d 'Print history of clipboard'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "update" -d 'Update clip with <id>'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "edit" -d 'Edit clip with <id>'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "remove" -d 'Remove clips with [ids]'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "promote" -d 'Replace content of clipboard with clip with <id>'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "clear" -d 'Remove all clips in clipboard'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "length" -d 'Print length of clipboard history'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "enable-watcher" -d 'Enable clipboard watcher'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "disable-watcher" -d 'Disable clipboard watcher'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "toggle-watcher" -d 'Toggle clipboard watcher'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "get-watcher-state" -d 'Get clipboard watcher state'
complete -c clipcatctl -n "__fish_clipcatctl_needs_command" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand version" -l client -d 'If true, shows client version only (no server required).'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand version" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand completions" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand default-config" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand insert" -s k -l kinds -d 'Specify which clipboard to insert ("clipboard", "primary", "secondary")' -r
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand insert" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand load" -s k -l kinds -d 'Specify which clipboard to insert ("clipboard", "primary", "secondary")' -r
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand load" -s m -l mime -d 'Specify the MIME type of the content' -r
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand load" -s f -l file -r -F
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand load" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand save" -s k -l kind -d 'Specify which clipboard to extract ("clipboard", "primary", "secondary")' -r
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand save" -s f -l file -r -F
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand save" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand get" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand list" -l no-id
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand list" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand update" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand edit" -s e -l editor -r
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand edit" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand remove" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand promote" -s k -l kinds -d 'Specify which clipboard to insert ("clipboard", "primary", "secondary")' -r
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand promote" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand clear" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand length" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand enable-watcher" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand disable-watcher" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand toggle-watcher" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand get-watcher-state" -s h -l help -d 'Print help'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "version" -d 'Print the client and server version information'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "completions" -d 'Output shell completion code for the specified shell (bash, zsh, fish)'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "default-config" -d 'Output default configuration'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "insert" -d 'Insert new clip into clipboard'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "load" -d 'Loads file into clipboard'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "save" -d 'Paste content of current clipboard into file'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "get" -d 'Print clip with <id>'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "list" -d 'Print history of clipboard'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "update" -d 'Update clip with <id>'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "edit" -d 'Edit clip with <id>'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "remove" -d 'Remove clips with [ids]'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "promote" -d 'Replace content of clipboard with clip with <id>'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "clear" -d 'Remove all clips in clipboard'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "length" -d 'Print length of clipboard history'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "enable-watcher" -d 'Enable clipboard watcher'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "disable-watcher" -d 'Disable clipboard watcher'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "toggle-watcher" -d 'Toggle clipboard watcher'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "get-watcher-state" -d 'Get clipboard watcher state'
complete -c clipcatctl -n "__fish_clipcatctl_using_subcommand help; and not __fish_seen_subcommand_from version completions default-config insert load save get list update edit remove promote clear length enable-watcher disable-watcher toggle-watcher get-watcher-state help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
