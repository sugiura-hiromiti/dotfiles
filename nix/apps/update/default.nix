{
  lib,
  pkgs,
  source,
  system,
  hosts,
  hostNames,
  mkTargetConfigEntries,
}:
let
  plan = import ./plan.nix {
    inherit
      lib
      system
      hosts
      hostNames
      mkTargetConfigEntries
      ;
  };
  planFile = pkgs.writeText "dotfiles-update-plan.json" (builtins.toJSON plan.data);
  mkUpdateScript = import ./script.nix { inherit lib pkgs; };
  updateScript = mkUpdateScript {
    inherit planFile source;
  };
in
{
  type = "app";
  meta.description = "Update flake inputs and switch the current host configuration";
  program = toString updateScript;
}
