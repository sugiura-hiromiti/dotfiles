if (sys host | get name) == "Darwin" {
	$env.PATH = (
		($env.PATH? | default [] | if ($in | describe) == "string" { $in | split row (char esep) } else { $in })
		| prepend [
			"/run/current-system/sw/bin"
			"/nix/var/nix/profiles/default/bin"
			$"($env.HOME)/.nix-profile/bin"
		]
	)
}

$env.config.buffer_editor = 'nvim'
$env.EDITOR = 'nvim'
$env.WALLPAPER_DIR = $'($env.HOME)/Downloads/media/wallpapers'
$env.XDG_CONFIG_HOME = $'($env.HOME)/.config'
$env.GITHUB_PAT_TOKEN = (
	open ~/.github_auth | lines | get 0 | split row ':' | get 2 | split row '@' | get 0
)
$env.path = ($env.path | prepend $'($env.HOME)/.cargo/bin')
$env.config.hooks.env_change.PWD = ( $env.config.hooks.env_change.PWD? | default [] | append { code: { |_,_|
	let rslt = s
	print $rslt
}} )
$env.config.hooks.pre_prompt = ($env.config.hooks.pre_prompt? | default [] | append {|| print -n "\u{1b}]133;A\u{7}"})
$env.config.hooks.pre_execution = ($env.config.hooks.pre_execution? | default [] | append {|| print -n "\u{1b}]133;C\u{7}"})
# $env.config.hooks.post_execution = (
# 	$env.config.hooks.post_execution?
# 	| default []
# 	| append {|| print -n $"\u{1b}]133;D;($env.LAST_EXIT_CODE)\u{7}"}
# )
$env.config.completions = {
	case_sensitive: false,
	quick: true,
	partial: true,
	algorithm: 'fuzzy',
	external: {
		enable: true,
		max_results: 200,
		completer: null,
	}
}
$env.config.footer_mode = 'always'

alias n = nvim
alias wh = which -a

# def fzl_cliphist [] {
# 	cliphist list | fuzzel -d --prompt "Clipboard " | cliphist decode | wl-copy
# }
# def fzl_core [] {
# 	['apps', 'clipboard', 'power'] | to text | fuzzel -d | str trim | match $in {
# 		'apps' => { fuzzel }
# 		'clipboard' => { fzl_cliphist }
# 		'power' => { fzl_power }
# 	}
# }
# def fzl_power [] {
# 	let action = (
# 		['suspend', 'shutdown', 'reboot'] | to text | fuzzel -d --prompt 'power' | str trim
# 	)
# 	switch $action {}
# }

def hour [] {
	date now | format date '%H' | into int
}
def auto_theme [] {
	hour | if 6 < $in and 18 > $in { set_theme light } else { set_theme light }
}
def "set_theme dark" [] { dconf write /org/gnome/desktop/interface/color-scheme '"prefer-dark"' }
def "set_theme light" [] { dconf write /org/gnome/desktop/interface/color-scheme '"prefer-light"' }
# def rw [] {
# 	let files = (ls $env.WALLPAPER_DIR | where type == file | get name)
# 	let idx = random int ..(($files | length) - 1)
# 	let file = ($files | get $idx)
# 	awww img $file
# }
def u [] {
	use std/dirs
	dirs add $'($env.HOME)/dotfiles/nix'
	let who = whoami
	let theme = (hour | if 5 < $in and $in < 17 { 'light' } else { 'dark' })
	let has_gui = if (wh dconf | is-empty) { false } else { true }
	echo $'{}:{ user = "($who)"; theme = "($theme)"; has_gui = ($has_gui);}' | save -f secret.nix
	sudo -v
	nix run .#update
	dirs drop
}
# def s [glob?] {
# 	let glob = $glob | default "."
# 	let git_state = (try {
# 		git status --porcelain=1 -- $glob | lines | each { |l|
# 			let path = ($l | str substring 3.. | path split | first)
# 			if ($l | str starts-with "??") {
# 				{
# 					path: $path,
# 					code: [" ", "N"]
# 				}
# 			} else {
# 				{
# 					path: $path,
# 					code: ($l | str substring 0..1 | split chars)
# 				}
# 			}
# 		} |
# 		group-by path |
# 		transpose path entries |
# 		each {|r|
# 			let index_code = (
# 				$r.entries |
# 				each {|e| $e.code | get 0 } |
# 				sort -r |
# 				first
# 			)
# 			let worktree_code = (
# 				$r.entries |
# 				each {|e| $e.code | get 1 } |
# 				sort -r |
# 				first
# 			)
# 			{
# 				name: $r.path,
# 				git: ([$index_code, $worktree_code] | each {|c| if $c == " " { "-" } else {$c}} | str join "" )
# 			}
#    	}
# 	} catch { [] })
# 	let list = (ls -al $glob | join -l $git_state name)
# 	$list |
# 	if ($git_state | is-empty) {
# 		select type name mode size num_links modified
# 	} else {
# 		select type git name mode size num_links modified
# 	} |
# 	sort-by type name
# }

def s [glob?] {
	let glob = $glob | default "."
	ls -al $glob | select type name mode size num_links modified
}
