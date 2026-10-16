set -eu

state=${BUILD_INSTALLER_TEST_STATE:?BUILD_INSTALLER_TEST_STATE is required}

if [ "$1" = eval ]; then
  mkdir -p "$state"
  # Use real flake evaluation so implicit current-system lookup cannot hide
  # cross-system selection bugs. Only the expensive ISO build is simulated.
  eval_store="$(cd "$state" && pwd -P)/nix-store"
  if [ "$5" = "path:${5#path:}" ] && [ "${5##*#}" = packages ]; then
    printf '%s\n' "${5%#packages}" > "$state/catalog-reference"
    exec "$REAL_NIX" --store "$eval_store" "$@"
  fi
  test "$#" -eq 5
  test "$2" = --json
  test "$3" = --no-update-lock-file
  test "$4" = --no-write-lock-file
  stage_and_output=${5#path:}
  stage=${stage_and_output%%#*}
  attribute=${stage_and_output#*#}
  attribute=${attribute%.installerIdentity}
  package=${attribute##*.}
  test "$(cat "$stage/tracked.txt")" = 'modified working-copy bytes'
  mkdir -p "$state"
  count=0
  if [ -e "$state/eval-count" ]; then
    count=$(cat "$state/eval-count")
  fi
  count=$((count + 1))
  printf '%s\n' "$count" > "$state/eval-count"
  printf '%s\n' "$package" > "$state/eval-package-$count"
  printf '%s\n' "$stage" > "$state/eval-stage-path-$count"
  exec "$REAL_NIX" --store "$eval_store" "$@"
fi

if [ "$#" -ne 5 ] \
  || [ "$1" != build ] \
  || [ "$3" != --no-link ] \
  || [ "$4" != --print-out-paths ] \
  || [ "$5" != --no-update-lock-file ]
then
  printf 'unexpected nix invocation:' >&2
  printf ' %s' "$@" >&2
  printf '\n' >&2
  exit 64
fi

case "$2" in
  path:*#packages.*.installer-*) ;;
  *)
    printf 'unexpected installer flake reference: %s\n' "$2" >&2
    exit 64
    ;;
esac

stage_and_output=${2#path:}
stage=${stage_and_output%%#*}
attribute=${stage_and_output#*#}
package=${attribute##*.}
repository=${BUILD_INSTALLER_TEST_REPOSITORY:?BUILD_INSTALLER_TEST_REPOSITORY is required}
case "$stage/" in
  "$repository"/*)
    printf 'stage was created inside the checkout: %s\n' "$stage" >&2
    exit 65
    ;;
esac
mkdir -p "$state"
count_file="$state/count"
if [ -e "$count_file" ]; then
  count=$(cat "$count_file")
else
  count=0
fi
count=$((count + 1))
printf '%s\n' "$count" > "$count_file"
printf '%s\n' "$package" > "$state/package-$count"
printf '%s\n' "$attribute" > "$state/attribute-$count"
printf '%s\n' "$stage" > "$state/stage-path-$count"
case "$package" in
  installer-selection-test-host|installer-selection-test-host--deployment-qemu|installer-test-host--deployment-qemu--theme-dark--session-tty|installer-selection-host--deployment-qemu--theme-dark--session-tty|installer-selection-arm-host) ;;
  *)
    printf "flake does not provide attribute '%s'\n" "$package" >&2
    exit 1
    ;;
esac
cp -a -- "$stage" "$state/stage-$count"
printf '/nix/store/fake-installer-%s\n' "$count"
