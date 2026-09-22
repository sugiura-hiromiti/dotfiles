set -eu

repository=${BUILD_INSTALLER_TEST_REPOSITORY:?BUILD_INSTALLER_TEST_REPOSITORY is required}
stage="$repository/in-checkout-stage"
mkdir -p "$stage"
printf '%s\n' "$stage"
