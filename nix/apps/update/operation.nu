def fail-evaluation [target: record, result: record] {
	if not ($result.stderr | is-empty) { print -e $result.stderr }
	error make {msg: $"candidate evaluation failed for ($target.name): exit code ($result.exit_code)"}
}
def validate-candidate [flake_ref: string, targets: list<record>] {

	# This slice preserves local-only behavior; the default policy remains unresolved.
	for target in $targets {
		let result = (
			^nix eval --raw $"($flake_ref)#($target.eval)" | complete
		)
		if $result.exit_code != 0 { fail-evaluation $target $result }
	}
}
def authorize [targets: list<record>] {
	for target in $targets {
		if not ($target.authorize | is-empty) {
			run-external ...$target.authorize
		}
	}
}
def activate [flake_ref: string, targets: list<record>] {
	for target in $targets {
		run-external ...$target.switch $"($flake_ref)#($target.name)"
	}
}
def operation-lock-path [repository: string] {
	let result = (
		run-external $GIT "-C" $repository rev-parse "--path-format=absolute" "--git-common-dir" | complete
	)
	if $result.exit_code != 0 {
		if not ($result.stderr | is-empty) { print -e $result.stderr }
		error make {msg: "update must run from a Git working tree"}
	}
	$result.stdout
	| str trim
	| path expand --strict
	| path join "dotfiles-update.lock"
}
def acquire-operation-lock [repository: string] {
	let lock = operation-lock-path $repository
	let result = run-external $MKDIR $lock | complete
	if $result.exit_code != 0 {
		error make {msg: $"dependency update is already running; lock: ($lock)"}
	}
	$lock
}
def publish-candidate [flake: string, repository: string] {
	cp -f ($flake | path join "flake.lock") ($repository | path join "flake.lock")
}
def run-operation [repository: string, source: string, targets: list<record>] {
	let lock = acquire-operation-lock $repository
	try {
		let temporary = (mktemp -d)
		let flake = $temporary | path join "source"
		try {
			cp -r $source $flake
			^chmod -R u+w $flake
			let flake_ref = $"path:($flake)"
			^nix flake update --flake $flake_ref
			validate-candidate $flake_ref $targets
			authorize $targets
			publish-candidate $flake $repository
			activate $flake_ref $targets
		} finally {
			if ($temporary | path exists) { rm -rf $temporary }
		}
	} finally {
		if ($lock | path exists) { rm -rf $lock }
	}
}
