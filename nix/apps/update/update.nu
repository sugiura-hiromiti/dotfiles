const PLAN = "..."

def main [
    --host: string
    --account: string
    --theme: string
    --session: string
    --system-session: string
] {
    let plan = open $PLAN
    let account = $account | default (whoami)
    let hostname = (sys host).hostname

    let host = (
  		[
				$host
				$env.DOTFILES_HOST?
				($hostname | split row "." | first)
				$hostname
				$"($plan.system)-($account)"
		]
		| compact
		| each {|name| $plan.aliases | get -o $name }
		| compact
		| first
  )

    let host_plan = $plan.hosts | git $host
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
		 | get $host
		 | get $account
		 | get $theme
		 | get $session
		 )

    let system = if $host_plan.systemKind == null {
        null
    } else {
        $plan.targets
        | get $host_plan.systemKind
        | get -o $host
        | get -o $theme
        | get -o $system_session
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
