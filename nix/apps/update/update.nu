def key [...path: string] {
	get -o ($path | into cell-path)
}
def read-identity [] {
	if not ($IDENTITY | path exists) { return null }
	let identity = try {
		open --raw $IDENTITY | from json
	} catch {
		error make $"invalid installed identity: ($IDENTITY)"
	}
	if not (($identity | describe) | str starts-with "record") {
		error make $"invalid installed identity: ($IDENTITY) requires host and deployment strings"
	}
	for field in [host deployment] {
		let value = $identity | key $field
		if ($value | describe) != "string" {
			error make $"invalid installed identity: ($IDENTITY) requires a non-empty ($field) string"
		}
		if ($value | str trim) == "" {
			error make $"invalid installed identity: ($IDENTITY) requires a non-empty ($field) string"
		}
	}
	$identity
}
def main [
	--host: string
	--deployment: string
	--account: string
	--theme: string
	--session: string
	--system-session: string
] {
	let plan = open $PLAN
	let account = $account | default (whoami | str trim)
	let hostname = (sys host).hostname
	let explicit_host = $host != null
	let host_identity = if $explicit_host { null } else { read-identity }
	let candidates = if $host != null {
		[$host]
	} else {
		[
			$host_identity.host?
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
		| get -o 0
  )
	if $host == null { error make "could not resolve target host" }
	let host_plan = $plan.hosts | key $host
	let theme = $theme | default ($plan.themeByHour | get (date now | format date "%H"))
	let mode = if (
		 (($env.WAYLAND_DISPLAY? | default "") != "")
		 or (($env.DISPLAY? | default "") != "")
		 ) { "gui" } else { "tty" }
	let session = $session | default ($host_plan.autoSession | get $mode)
	let runtime_kind = if $nu.os-info.name == "macos" {
		"darwin"
	} else if $nu.os-info.name == "linux" and ("/etc/os-release" | path exists) and (open --raw /etc/os-release | str contains "ID=nixos") {
		"nixos"
	} else { null }
	if $runtime_kind == "nixos" and $system_session != null {
		error make "--system-session is not supported on NixOS; use --session"
	}
	let system_session = $system_session | default $host_plan.defaultSession
	let effective_system_session = if $runtime_kind == "nixos" {
		$session
	} else {
		$system_session
	}
	let system = if $host_plan.system == null or $runtime_kind != $host_plan.system.kind {
		null
	} else {
		let identity = if $deployment != null {
			null
		} else if $explicit_host {
			read-identity
		} else {
			$host_identity
		}
		let identity_matches = $identity != null and (($plan.aliases | key $identity.host) == $host)
		let deployment = if $deployment != null {
			$deployment
		} else if $identity_matches {
			$identity.deployment
		} else {
			$host_plan.defaultDeployment
		}
		if $deployment == null {
			error make $"could not resolve deployment for ($host); supply --deployment"
		}
		if $deployment not-in $host_plan.deployments {
			if $identity_matches {
				error make $"installed identity deployment is not declared for ($host): ($deployment)"
			}
			error make $"deployment is not declared for ($host): ($deployment)"
		}
		let target = $host_plan.system.targets | key $deployment $theme $effective_system_session
		if $target == null {
			error make $"system configuration is not defined for ($host)/($deployment): kind=($host_plan.system.kind), theme=($theme), session=($effective_system_session)"
		}
		if $host_plan.system.kind == "nixos" and not $target.ready {
			error make $"deployment requires a Facter report: ($host)/($deployment)"
		}
		$target
	}
	let home = if $runtime_kind == "nixos" and $system != null {
		null
	} else {
		let target = $host_plan.home | key $account $theme $session
		if $target == null {
			error make $"home configuration is not defined for ($host): account=($account), theme=($theme), session=($session)"
		}
		$target
	}
	let repository = pwd | path expand --strict
	let targets = if $runtime_kind == "nixos" and $system != null {
		[$system]
	} else {
		[$home $system] | compact
	}
	run-operation $repository $SOURCE $targets
}
