set -eu

state=${TEST_STATE:?TEST_STATE is required}
mkdir -p "$state"

last=
for argument in "$@"; do
  last=$argument
done

if [ "$1" = flake ] && [ "$2" = update ]; then
  flake=
  output=
  previous=
  for argument in "$@"; do
    if [ "$previous" = --flake ]; then flake=$argument; fi
    if [ "$previous" = --output-lock-file ]; then output=$argument; fi
    previous=$argument
  done
  if [ -z "$output" ]; then output="$flake/flake.lock"; fi
  printf '%s\n' "${TEST_CANDIDATE:?TEST_CANDIDATE is required}" > "$output"
  printf '%s\n' "$TEST_CANDIDATE" >> "$state/generated"
  exit 0
fi

if [ "$1" = eval ]; then
  reference=
  previous=
  for argument in "$@"; do
    if [ "$previous" = --reference-lock-file ]; then reference=$argument; fi
    previous=$argument
  done
  flake=${last%%#*}
  target=${last#*#}
  if [ -n "$reference" ]; then lock=$reference; else lock="$flake/flake.lock"; fi
  printf '%s %s\n' "$(cat "$flake/source-marker")" "$(cat "$lock")" >> "$state/preflight"
  printf '%s\n' "$target" >> "$state/preflight-targets"
  if [ "${TEST_FAIL_PREFLIGHT:-0}" = 1 ] || \
     [ "${TEST_FAIL_PREFLIGHT_TARGET:-}" = "$target" ]
  then
    printf '%s\n' 'forced preflight failure' >&2
    exit 23
  fi
  if [ "${TEST_BLOCK_PREFLIGHT:-0}" = 1 ]; then
    : > "$state/preflight-waiting"
    while [ ! -e "$state/release-preflight" ]; do sleep 0.05; done
  fi
  printf '%s\n' /nix/store/test.drv
  exit 0
fi

if [ "$1" = run ] && [ "$2" = nixpkgs#home-manager ]; then
  flake=${last%%#*}
  printf '%s %s\n' "$(cat "$flake/source-marker")" "$(cat "$flake/flake.lock")" >> "$state/activation"
  if [ "${TEST_FAIL_ACTIVATION:-0}" = 1 ]; then
    printf '%s\n' 'forced activation failure' >&2
    exit 24
  fi
  exit 0
fi

printf 'unexpected fake nix invocation:' >&2
printf ' %s' "$@" >&2
printf '\n' >&2
exit 64
