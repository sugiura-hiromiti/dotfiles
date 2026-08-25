def key [...path: string] {
	 get -o ($path | into cell-path)
}

def exec-plan [command: list<string> ...args: string] {
	 run-external ...$command ...$args
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

let runtime_kind = if $nu.os-info.name == "macos" {
"darwin"
} else if ($nu.os-info.name == "linux" and ("/etc/os-release" | path exists) and (open --raw /etc/os-release | str contains "ID=nixos")) {
"nixos"
} else {null}

let system = if $runtime_kind != $host_plan.systemKind {
    null
} else {
    $plan.targets
    | key $host_plan.systemKind $host $theme $system_session
}

    # TODO: path:修飾やめたい
    let flake = $"path:(pwd)"
	 let lock = (pwd | path join "flake.lock")
	 let tmp = (mktemp -d)
	 let candidate = ($tmp | path join "flake.lock")
	 let home_action = ($plan.actions | key $home.action)
	 let system_action = if $system == null {
	 	  null
		  } else {
		  $plan.actions | key $system.action
		  }

		  try {
		  exec-plan $plan.commands.update "--flake" $flake "--output-lock-file" $candidate
		  exec-plan $plan.commands.eval "--reference-lock-file" $candidate $"($flake)#($home.eval)" | ignore
		  if $system != null {
		  exec-plan $plan.commands.eval "--reference-lock-file" $candidate $"($flake)#($system.eval)" | ignore
		  if not ($system_action.authorize | is-empty) {
		  exec-plan $system_action.authorize
}
}

cp $candidate $lock
exec-plan $home_action.switch $"($flake)#($home.name)"
if $system != null {
exec-plan $system_action.switch $"($flake)#($system.name)"
}

} finally {
rm -rf $tmp
}
}
