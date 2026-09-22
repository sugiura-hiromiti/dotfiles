def print-command-error [result: record] {
	if ($result.stderr | is-not-empty) {
		print --stderr --no-newline $result.stderr
	}
}
def main [--host: string] {
	if $host == null or ($host | is-empty) {
		error make "--host is required"
	}
	let root_result = (^$JJ --ignore-working-copy root | complete)
	if $root_result.exit_code != 0 {
		print-command-error $root_result
		exit $root_result.exit_code
	}
	let repository = $root_result.stdout | str trim | path expand --strict
	cd $repository
	let list_result = (
		^$JJ --config 'snapshot.auto-track="none()"' file list -r @ -T 'json(path) ++ "\n"' | complete
	)
	if $list_result.exit_code != 0 {
		print-command-error $list_result
		exit $list_result.exit_code
	}
	let paths = $list_result.stdout | lines | each { from json }
	let stage_result = (
		^$MKTEMP --directory --tmpdir=/tmp dotfiles-installer-source.XXXXXXXXXX
		| complete
	)
	if $stage_result.exit_code != 0 {
		print-command-error $stage_result
		exit $stage_result.exit_code
	}
	let stage = $stage_result.stdout | str trim | path expand --strict
	if $stage == $repository or ($stage | str starts-with $"($repository)/") {
		^$RM --recursive --force -- $stage
		error make $"refusing to stage inside the checkout: ($stage)"
	}
	for path in $paths {
		let copy_result = (
			^$CP --archive --parents --no-dereference -- $path $stage | complete
		)
		if $copy_result.exit_code != 0 {
			print-command-error $copy_result
			^$RM --recursive --force -- $stage
			exit $copy_result.exit_code
		}
	}
	let build_result = (
		^$NIX build $"path:($stage)#installer-($host)"
			--no-link
			--print-out-paths
			--no-update-lock-file
		| complete
	)
	^$RM --recursive --force -- $stage
	print-command-error $build_result
	if ($build_result.stdout | is-not-empty) {
		print --no-newline $build_result.stdout
	}
	if $build_result.exit_code != 0 {
		exit $build_result.exit_code
	}
}
