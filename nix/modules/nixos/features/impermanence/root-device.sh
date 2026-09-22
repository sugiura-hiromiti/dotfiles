set -euo pipefail
if devices=$(blkid -c /dev/null -t "PARTLABEL=$1" -o device); then
  :
else
  status=$?
  if [ "$status" -ne 2 ]; then
    echo "Failed to enumerate root devices" >&2
    exit "$status"
  fi
fi
matches=()
while IFS= read -r device; do
  [ -z "$device" ] || matches+=("$device")
done <<< "$devices"
if [ "${#matches[@]}" -ne 1 ]; then
  echo "Expected exactly one PARTLABEL=$1 device; found ${#matches[@]}" >&2
  exit 1
fi
printf '%s\n' "${matches[0]}"
