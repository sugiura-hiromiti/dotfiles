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
$"($plan.system)-($account)"
] | compact
}

    let host = (
	 	  $candidates
		| each {|name| $plan.aliases | key $name }
		| compact
		| first
  )

if $host == null {
error make "could not resolve target host"
}

    let host_plan = $plan.hosts | key $host
    let theme = $theme | default (
  		$plan.themeByHour | get (date now | format date "%H")
	)
    let mode = if (
		 (($env.WAYLAND_DISPLAY? | default "") != "")
		 or (($env.DISPLAY? | default "") != "")
		 ) { "gui" } else { "tty" }

    let session = $session | default ($host_plan.autoSession | get $mode)
    let system_session = $system_session | default $host_plan.defaultSession
    let home = (
		 $plan.targets.home
		 | key $host $account $theme $session
		 )

if $home == null {
error make $"home configuration is not defined for ($host): account=($account), theme=($theme), session=($session)"
}

    let system = if $host_plan.systemKind == null {
        null
    } else {
        $plan.targets
        | key $host_plan.systemKind $host $theme $system_session
    }

    {
        host: $host
        account: $account
        theme: $theme
        session: $session
        system_session: $system_session
        home: $home
        system: $system
    }
}
