{ lib }:
# NOTE: 将来的に
# resolveProfiles { inherit target; config = targetConfig; }
# のようにするかもしれない
# callerが持っているのは本来target configのみなのだから
{
  target,
  system,
  os,
  host,
  variantProfiles ? [ ],
}:
let
  profileRoot = ../profiles;
  optionalFile = path: lib.optionals (builtins.pathExists path) [ path ];
  profileDir = kind: name: "${profileRoot}/${kind}/${name}";
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
in
lib.unique (
  perKindMaybe "os" "OS" os
  ++ perKindMaybe "systems" "system" system
  ++ perKindMaybe "hosts" "host" host
  ++ lib.concatMap (profile: perKind "variants" "variant" profile) variantProfiles
)
