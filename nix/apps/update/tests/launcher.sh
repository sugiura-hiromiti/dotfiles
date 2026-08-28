set -eu

launcher_root=$(mktemp -d)
trap 'rm -rf "$launcher_root"' EXIT

launcher_home="$launcher_root/home"
launcher_state="$launcher_root/state"
mkdir -p "$launcher_home/dotfiles" "$launcher_state"
touch "$launcher_home/dotfiles/flake.nix"

if env \
  HOME="$launcher_home" \
  LAUNCHER_STATE="$launcher_state" \
  nu --config "$LAUNCHER_CONFIG" \
    --commands '$env.PATH = ($env.PATH | prepend $"($env.LAUNCHER_BIN)/bin"); u'
then
  printf '%s\n' 'launcher failure unexpectedly succeeded' >&2
  exit 1
fi

test -f "$launcher_state/args"
if [ -e "$launcher_home/dotfiles/flake.lock" ]; then
  printf '%s\n' 'launcher published sentinel flake.lock before failing' >&2
fi
test ! -e "$launcher_home/dotfiles/flake.lock"
test "$(cat "$launcher_state/args")" = \
  "$(printf '%s\n' run --no-write-lock-file '.#update' --)"
