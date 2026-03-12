{ lib }:
{
  baseDir,
  target,
  platform,
  system,
  host,
  user,
  roles ? [ ],
  variants ? [ ],
}:
let
  base = toString baseDir;
  optional = path: lib.optionals (builtins.pathExists path) [ path ];
  perKind =
    kind: name:
    let
      dir = "${base}/profiles/${kind}/${name}";
    in
    optional "${dir}/common.nix" ++ optional "${dir}/${target}.nix";
  perKindMaybe = kind: name: if name == null || name == "" then [ ] else perKind kind name;
in
lib.unique (
  perKindMaybe "platforms" platform
  ++ perKindMaybe "systems" system
  ++ perKindMaybe "hosts" host
  ++ perKindMaybe "users" user
  ++ lib.concatMap (role: perKind "roles" role) roles
  ++ lib.concatMap (variant: perKind "variants" variant) variants
)
