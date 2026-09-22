set -eu

state=${TEST_STATE:?TEST_STATE is required}
command=${1:-}
shift || true

frozen_lock_count=0
for argument in "$@"; do
  if [ "$argument" = --no-update-lock-file ]; then
    frozen_lock_count=$((frozen_lock_count + 1))
  fi
done

case "$command" in
  store)
    test "$1" = add-path
    shift
    test "$#" -eq 1
    count=0
    if [ -e "$state/store-add-count" ]; then
      count=$(cat "$state/store-add-count")
    fi
    count=$((count + 1))
    printf '%s\n' "$count" > "$state/store-add-count"
    test "$count" -eq 1
    source=$1
    rm -rf "$state/store-snapshot"
    cp -a "$source" "$state/store-snapshot"
    chmod -R a-w "$state/store-snapshot"
    printf '%s\n' "$state/store-snapshot"
    ;;
  eval)
    printf '%s\n' "$@" > "$state/eval-args"
    test "$frozen_lock_count" -eq 1
    if [ "${TEST_LOCK_INVALID:-0}" = 1 ]; then
      exit 71
    fi
    if [ "${TEST_MUTATE_WORKSPACE:-0}" = 1 ]; then
      printf '%s\n' mutated > "$TEST_WORK_SOURCE/source-marker"
    fi
    cat "${TEST_METADATA:?TEST_METADATA is required}"
    ;;
  build)
    printf '%s\n' "$@" > "$state/build-args"
    test "$frozen_lock_count" -eq 1
    if [ "${TEST_BUILD_FAIL:-0}" = 1 ]; then
      exit 72
    fi
    printf '%s\n' "${TEST_DISKO:?TEST_DISKO is required}"
    ;;
  *)
    printf 'unexpected nix command: %s\n' "$command" >&2
    exit 64
    ;;
esac
