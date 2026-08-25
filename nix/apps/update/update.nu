const PLAN = "..."

def key [name: string] {
	 get -o ([$name] | into cell-path)
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

let candidates=if $host != null {
[$host]
} else {
[
$env.DOTFILES_HOST?
($hostname | split row "." | first)
$hostname
$"($plan.system)-$account"
] | compact
}

    let host = (
	 	  $candidate
		| each {|name| $plan.aliases | get -o $name }
		| compact
		| first
  )

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
		 | key $host
		 | key $account
		 | key $theme
		 | key $session
		 )

    let system = if $host_plan.systemKind == null {
        null
    } else {
        $plan.targets
        | key $host_plan.systemKind
        | key -o $host
        | key -o $theme
        | key -o $system_session
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
