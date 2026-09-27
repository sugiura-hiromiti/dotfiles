set -eu

state=${BUILD_INSTALLER_TEST_STATE:?BUILD_INSTALLER_TEST_STATE is required}

if [ "$1" = eval ]; then
  test "$#" -eq 5
  test "$2" = --json
  test "$3" = --no-update-lock-file
  test "$4" = --no-write-lock-file
  stage_and_output=${5#path:}
  stage=${stage_and_output%%#installer-*}
  package=${stage_and_output#*#}
  package=${package%.installerIdentity}
  test "$5" = "path:$stage#$package.installerIdentity"
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
  case "$package" in
    installer-test-host--deployment-qemu--theme-dark--session-tty)
      printf '%s' '{"host":"test-host","deployment":"qemu","target":"test-host--deployment-qemu--theme-dark--session-tty"}' ;;
    installer-selection-test-host)
      printf '%s' '{"host":"test-host","deployment":"parallels","target":"test-host--deployment-parallels--theme-dark--session-tty"}' ;;
    installer-selection-test-host--deployment-qemu)
      printf '%s' '{"host":"test-host","deployment":"qemu","target":"test-host--deployment-qemu--theme-dark--session-tty"}' ;;
    installer-selection-host--deployment-qemu--theme-dark--session-tty)
      printf '%s' '{"host":"selection-host","deployment":"qemu","target":"selection-host--deployment-qemu--theme-dark--session-tty"}' ;;
    *)
      printf "flake does not provide attribute '%s'\n" "$package" >&2
      exit 1 ;;
  esac
  exit 0
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
  path:*#installer-*) ;;
  *)
    printf 'unexpected installer flake reference: %s\n' "$2" >&2
    exit 64
    ;;
esac

stage_and_output=${2#path:}
stage=${stage_and_output%%#installer-*}
package=installer-${stage_and_output#*#installer-}
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
printf '%s\n' "$stage" > "$state/stage-path-$count"
case "$package" in
  installer-selection-test-host|installer-selection-test-host--deployment-qemu|installer-test-host--deployment-qemu--theme-dark--session-tty|installer-selection-host--deployment-qemu--theme-dark--session-tty) ;;
  *)
    printf "flake does not provide attribute '%s'\n" "$package" >&2
    exit 1
    ;;
esac
cp -a -- "$stage" "$state/stage-$count"
printf '/nix/store/fake-installer-%s\n' "$count"
