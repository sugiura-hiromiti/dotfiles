{ lib }:
{
  baseDir,
  target,
  platform,
  system,
  host,
  roles ? [ ],
  variants ? [ ],
  themeProfiles ? [ ],
  sessionProfiles ? [ ],
  accountVariants ? [ ],
}:
let
  base = toString baseDir;
  optionalFile = path: lib.optionals (builtins.pathExists path) [ path ];
  profileDir = kind: name: "${base}/profiles/${kind}/${name}";
  requireProfileDir =
    kind: label: name:
    let
      dir = profileDir kind name;
    in
    assert lib.assertMsg (builtins.pathExists dir)
      "Unknown ${label} profile '${name}' for ${target} target";
    dir;
  perKind =
    kind: label: name:
    let
      dir = requireProfileDir kind label name;
    in
    optionalFile "${dir}/common.nix" ++ optionalFile "${dir}/${target}.nix";
  perKindMaybe =
    kind: label: name:
    if name == null || name == "" then [ ] else perKind kind label name;
  perVariant = label: name: perKind "variants" label name;
in
lib.unique (
  perKindMaybe "platforms" "platform" platform
  ++ perKindMaybe "systems" "system" system
  ++ perKindMaybe "hosts" "host" host
  ++ lib.concatMap (role: perKind "roles" "role" role) roles
  ++ lib.concatMap (variant: perVariant "variant" variant) variants
  ++ lib.concatMap (profile: perVariant "theme runtime" profile) themeProfiles
  ++ lib.concatMap (profile: perVariant "session runtime" profile) sessionProfiles
  ++ lib.concatMap (variant: perVariant "account variant" variant) accountVariants
)
