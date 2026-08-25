def key [...path: string] {
	get -o ($path | into cell-path)
}
def main [
	--host: string
	--account: string
	--theme: string
	--session: string
	--system-session: string
] {
	let plan = open $PLAN
	let account = $account | default (whoami | str trim)
	let hostname = (sys host).hostname
	let candidates = if $host != null {
		[$host]
	} else {
		[
			$env.DOTFILES_HOST?
			($hostname | split row "." | first)
			$hostname
			($plan.defaultHosts | key $account)
		] | compact
	}
	let host = (
		$candidates
		| each {|name| $plan.aliases | key $name }
		| compact
		| first
  )
	if $host == null { error make "could not resolve target host" }
	let host_plan = $plan.hosts | key $host
	let theme = $theme | default ($plan.themeByHour | get (date now | format date "%H"))
	let mode = if (
		 (($env.WAYLAND_DISPLAY? | default "") != "")
		 or (($env.DISPLAY? | default "") != "")
		 ) { "gui" } else { "tty" }
	let session = $session | default ($host_plan.autoSession | get $mode)
	let system_session = $system_session | default $host_plan.defaultSession
	let home = $host_plan.home | key $account $theme $session
	if $home == null { error make $"home configuration is not defined for ($host): account=($account), theme=($theme), session=($session)" }
	let runtime_kind = if $nu.os-info.name == "macos" {
		"darwin"
	} else if $nu.os-info.name == "linux" and ("/etc/os-release" | path exists) and (open --raw /etc/os-release | str contains "ID=nixos") {
		"nixos"
	} else { null }
	let system = if $host_plan.system == null or $runtime_kind != $host_plan.system.kind {
		null
	} else {
		let target = $host_plan.system.targets | key $theme $system_session
		if $target == null {
			error make $"system configuration is not defined for ($host): kind=($host_plan.system.kind), theme=($theme), session=($system_session)"
		}
		$target
	}

	# TODO: path:修飾やめたい
	let flake = $"path:(pwd)"
	let lock = pwd | path join "flake.lock"
	let tmp = (mktemp -d)
	let candidate = $tmp | path join "flake.lock"
	let targets = [$home $system] | compact
	try {
		(run-external
			...($plan.commands.update)
			"--flake"
			$flake
			"--output-lock-file"
			$candidate
		)
		for target in $targets {
			(run-external
				...($plan.commands.eval)
				"--reference-lock-file"
				$candidate $"($flake)#($target.eval)") | ignore
		}
		for target in $targets {
			if not ($target.authorize | is-empty) {
				run-external ...($target.authorize)
			}
		}
		cp $candidate $lock
		for target in $targets {
			run-external ...($target.switch) $"($flake)#($target.name)"
		}
	} finally {
		rm -rf $tmp
	}
}
