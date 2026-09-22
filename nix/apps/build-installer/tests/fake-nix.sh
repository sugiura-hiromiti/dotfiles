set -eu

state=${BUILD_INSTALLER_TEST_STATE:?BUILD_INSTALLER_TEST_STATE is required}

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
  path:*#installer-*) ;;
  *)
    printf 'unexpected installer flake reference: %s\n' "$2" >&2
    exit 64
    ;;
esac

stage_and_output=${2#path:}
stage=${stage_and_output%%#installer-*}
host=${stage_and_output#*#installer-}
repository=${BUILD_INSTALLER_TEST_REPOSITORY:?BUILD_INSTALLER_TEST_REPOSITORY is required}
case "$stage/" in
  "$repository"/*)
    printf 'stage was created inside the checkout: %s\n' "$stage" >&2
    exit 65
    ;;
esac
if [ "$host" != test-host ]; then
  printf 'unexpected installer host: %s\n' "$host" >&2
  exit 64
fi

mkdir -p "$state"
count_file="$state/count"
if [ -e "$count_file" ]; then
  count=$(cat "$count_file")
else
  count=0
fi
count=$((count + 1))
printf '%s\n' "$count" > "$count_file"
cp -a -- "$stage" "$state/stage-$count"
printf '/nix/store/fake-installer-%s\n' "$count"
