{ lib }:
{
  baseDir,
  target,
  platform,
  system,
  host,
  roles ? [ ],
  variants ? [ ],
}:
let
  base = toString baseDir;
  optionalFile = path: lib.optionals (builtins.pathExists path) [ path ];
  profileDir = kind: name: "${base}/profiles/${kind}/${name}";
  requireProfileDir =
    kind: name:
    let
      dir = profileDir kind name;
    in
    assert lib.assertMsg (builtins.pathExists dir)
      "Unknown ${kind} profile '${name}' for ${target} target";
    dir;
  perKind =
    kind: name:
    let
      dir = requireProfileDir kind name;
    in
    optionalFile "${dir}/common.nix" ++ optionalFile "${dir}/${target}.nix";
  perKindMaybe = kind: name: if name == null || name == "" then [ ] else perKind kind name;
in
lib.unique (
  perKindMaybe "platforms" platform
  ++ perKindMaybe "systems" system
  ++ perKindMaybe "hosts" host
  ++ lib.concatMap (role: perKind "roles" role) roles
  ++ lib.concatMap (variant: perKind "variants" variant) variants
)
