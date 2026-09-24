def fail [message: string] {
	error make {msg: $message}
}
def require [condition: bool, message: string] {
	if not $condition {
		fail $message
	}
}
def normalized-absolute-path [value: string, label: string] {
	require ($value | str starts-with "/") $"($label) must be absolute"
	let pieces = $value | split row "/" | skip 1
	require (
		($pieces | is-not-empty) and ($pieces | all {|piece| $piece != "" and $piece != "." and $piece != ".." })
	) $"($label) must be normalized and contain no traversal"
	let normalized = $"/($pieces | str join '/')"
	require ($normalized == $value) $"($label) must be normalized"
}
def validate-facter-relative-path [] {
	require (not ($FACTER_RELATIVE_PATH | str starts-with "/")) "facter path must be relative"
	let pieces = $FACTER_RELATIVE_PATH | split row "/"
	require (
		($pieces | is-not-empty) and ($pieces | all {|piece| $piece != "" and $piece != "." and $piece != ".." })
	) "facter path must be canonical and contain no traversal"
}
def validate-metadata [metadata: record] {
	let user = $metadata.primaryUser
	require (($user.name | describe) == "string") "primary user name must be a string"
	require ($user.name == $PRIMARY_ACCOUNT) $"primary user must be ($PRIMARY_ACCOUNT)"
	require (($user.home | describe) == "string") "primary user home must be a string"
	normalized-absolute-path $user.home "primary user home"
	require ($user.home != "/root") "primary user home must not be root's home"
	require (($user.uid | describe) == "int") "primary user UID must be an integer"
	require ($user.uid > 0) "primary user UID must be non-root"
	require (($user.group | describe) == "string") "primary group must be a string"
	require (($user.group | str trim | is-not-empty)) "primary group must not be empty"
	require (($user.gid | describe) == "int") "primary group GID must be an integer"
	require ($user.gid >= 0) "primary group GID must not be negative"
	require (($user.isNormalUser | describe) == "bool" and $user.isNormalUser) "primary user must be a normal user"
	require (
		($user.extraGroups | describe | str starts-with "list") and ($user.extraGroups | all {|group| ($group | describe) == "string" })
	) "primary user extraGroups must be a list of strings"
	require ("wheel" in $user.extraGroups) "primary user must belong to wheel"
	let expected_password = $"/persist/etc/dotfiles/password-($PRIMARY_ACCOUNT).hash"
	require (($user.hashedPasswordFile | describe) == "string") "hashed password file must be a string"
	require ($user.hashedPasswordFile == $expected_password) $"hashed password file must be ($expected_password)"
	require (($metadata.sudoEnabled | describe) == "bool" and $metadata.sudoEnabled) "sudo must be enabled"
	require (($metadata.mutableUsers | describe) == "bool" and not $metadata.mutableUsers) "users must be immutable"
	require (
		($metadata.boot.systemdBoot | describe) == "bool" and $metadata.boot.systemdBoot
	) "systemd-boot must be enabled"
	require (
		($metadata.boot.canTouchEfiVariables | describe) == "bool" and not $metadata.boot.canTouchEfiVariables
	) "EFI variable writes must be disabled"
	require (
		($metadata.boot.efiArch | describe) == "string" and $metadata.boot.efiArch == $EFI_ARCH
	) $"boot EFI architecture must be ($EFI_ARCH)"
	require (($metadata.preservation.backingPath | describe) == "string") "Preservation backing path must be a string"
	normalized-absolute-path $metadata.preservation.backingPath "Preservation backing path"
	require (($metadata.preservation.runtimePath | describe) == "string") "Preservation runtime path must be a string"
	normalized-absolute-path $metadata.preservation.runtimePath "Preservation runtime path"
	let expected_runtime = $"($user.home)/dotfiles"
	require ($metadata.preservation.runtimePath == $expected_runtime) $"Preservation runtime path must be ($expected_runtime)"
	require ($metadata.preservation.backingPath | str starts-with "/persist/") "Preservation backing path must be below /persist"
}
def collect-password [] {
	let password = (input --suppress-output "Administrator password: ")
	print ""
	let confirmation = (input --suppress-output "Confirm administrator password: ")
	print ""
	require ($password | is-not-empty) "administrator password must not be empty"
	require ($password == $confirmation) "administrator passwords do not match"
	let hash = $password + "\n" | ^$MKPASSWD --method=yescrypt --stdin | str trim
	require ($hash | str starts-with '$y$') "mkpasswd did not return a yescrypt hash"
	($hash + "\n") | save --force $PASSWORD_HASH
	^$CHMOD 0600 $PASSWORD_HASH
}
def prepare-post-facter-source [] {
	validate-facter-relative-path
	^$RM --recursive --force $RUNTIME_ROOT
	^$MKDIR --parents $WORK_SOURCE
	^$CP --archive $"($BASE_SOURCE)/." $WORK_SOURCE
	^$CHMOD --recursive u+w $WORK_SOURCE
	collect-password
	let facter_path = [$WORK_SOURCE $FACTER_RELATIVE_PATH] | path join
	^$MKDIR --parents ($facter_path | path dirname)
	^$FACTER -o $facter_path
	let post_source = (^$NIX store add-path $WORK_SOURCE | str trim)
	require ($post_source | is-not-empty) "Nix did not return a post-facter store path"
	let root_result = (
		do { ^$NIX_STORE --realise $post_source --add-root $POST_SOURCE_ROOT }
		| complete
	)
	require ($root_result.exit_code == 0) $"failed to root post-facter source: ($root_result.stderr | str trim)"
	$post_source
}
def evaluate-metadata [post_source: string] {
	let selector = $"path:($post_source)#nixosConfigurations.($TARGET).config.dotfiles.installer.metadata"
	let metadata = (^$NIX eval --json --no-update-lock-file $selector | from json)
	validate-metadata $metadata
	$metadata
}
def realize-disko [post_source: string] {
	let selector = $"path:($post_source)#nixosConfigurations.($TARGET).config.system.build.diskoScript"
	let paths = (
		^$NIX build --no-link --print-out-paths --no-update-lock-file $selector
		| lines
		| where {|line| $line | is-not-empty }
	)
	require (($paths | length) == 1) "Disko realization must return exactly one path"
	$paths.0
}
def eligible-disk [] {
	let report = (^$LSBLK --json --output PATH,TYPE,RM,HOTPLUG | from json)
	let eligible = ($report.blockdevices | where {|device|
    $device.type == "disk" and $device.rm == false and $device.hotplug == false
  })
	require (($eligible | length) == 1) $"expected exactly one eligible disk, found ($eligible | length)"
	$eligible.0.path
}
def create-target-alias [disk: string] {
	^$MKDIR --parents ($TARGET_ALIAS | path dirname)
	let readlink_result = do { ^$READLINK $TARGET_ALIAS } | complete
	if $readlink_result.exit_code == 0 {
		^$RM --force $TARGET_ALIAS
	} else if ($TARGET_ALIAS | path exists) {
		fail $"refusing to replace non-symlink target alias ($TARGET_ALIAS)"
	}
	^$LN --symbolic $disk $TARGET_ALIAS
}
def validate-mounts [] {
	for suffix in ["" "/nix" "/persist" "/boot"] {
		^$MOUNTPOINT --quiet $"($MOUNT_ROOT)($suffix)"
	}
}
def install-password [metadata: record] {
	let destination = $"($MOUNT_ROOT)($metadata.primaryUser.hashedPasswordFile)"
	let directory = $destination | path dirname
	^$MKDIR --parents $directory
	^$CHMOD 0755 ($directory | path dirname)
	^$CHOWN root:root $directory
	^$CHMOD 0700 $directory
	let temporary = $"($directory)/.password-hash-(random uuid).tmp"
	^$INSTALL --mode 0600 $PASSWORD_HASH $temporary
	^$CHOWN root:root $temporary
	^$CHMOD 0600 $temporary
	^$MV $temporary $destination
}
def install-dotfiles [post_source: string, metadata: record] {
	let destination = $"($MOUNT_ROOT)($metadata.preservation.backingPath)"
	^$MKDIR --parents $destination
	^$CP --archive $"($post_source)/." $destination
	^$CHMOD --recursive u+w $destination
	^$CHOWN --recursive $"($metadata.primaryUser.uid):($metadata.primaryUser.gid)" $destination
}
def run-installer [] {
	print $"Installing host ($HOST) as target ($TARGET)."
	let post_source = (prepare-post-facter-source)
	let metadata = (evaluate-metadata $post_source)
	let disko_script = (realize-disko $post_source)
	let disk = (eligible-disk)
	create-target-alias $disk
	^$disko_script
	validate-mounts
	# Disko inherits the private service umask. System mount roots must be
	# traversable by installed users; secret directories keep their own modes.
	^$CHMOD 0755 $MOUNT_ROOT $"($MOUNT_ROOT)/nix" $"($MOUNT_ROOT)/persist"
	install-password $metadata
	# nixos-install invokes nix and nix-env through PATH.
	with-env {PATH: ($env.PATH? | default [] | prepend ($NIX | path dirname))} {
		^$NIXOS_INSTALL --root $MOUNT_ROOT --flake $"path:($post_source)#($TARGET)" --no-update-lock-file --no-channel-copy --no-root-password
	}
	let fallback_loader = $"($MOUNT_ROOT)/boot/EFI/BOOT/BOOT($EFI_ARCH).EFI"
	require ($fallback_loader | path exists) $"fallback EFI loader is missing: ($fallback_loader)"
	install-dotfiles $post_source $metadata
	^$SYNC
	^$UMOUNT --recursive $MOUNT_ROOT
	^$POWEROFF
}
def main [] {
	try {
		run-installer
	} catch {|failure|
		print --stderr $failure.rendered
		print --stderr $"Installer failed: ($failure.msg)"
		print --stderr "Switch to tty2 with Ctrl+Alt+F2 for diagnostics."
		print --stderr "After correcting the problem, return to tty1 or run: systemctl restart dotfiles-installer.service"
		exit 1
	}
}
