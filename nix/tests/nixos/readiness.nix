{ lib, pkgs }:
let
  runtimeContexts = import ../../runtime-contexts.nix;
  registry = import ../../lib/hosts.nix {
    inherit lib runtimeContexts;
    hostDir = ../fixtures/hosts;
  };
  targets = import ../../lib/targets.nix {
    inherit lib;
    inherit (registry) hosts hostNames;
    runtime = import ../../lib/runtime.nix { inherit lib runtimeContexts; };
    targetNames = import ../../lib/target-names.nix { inherit lib; };
  };
in
assert registry.facterRelativePath "pending" == "nix/profiles/hosts/pending/facter.json";
assert !registry.hosts.pending.facterReady;
assert registry.hosts.ready.facterReady;
assert
  map (entry: entry.name) targets.declaredNixosTargetEntries == [
    "pending"
    "ready"
  ];
assert map (entry: entry.name) targets.readyNixosTargetEntries == [ "ready" ];
assert
  map (host: host.host) (targets.declaredNixosHostsForSystem "aarch64-linux") == [
    "pending"
    "ready"
  ];
assert targets.declaredNixosHostsForSystem "x86_64-linux" == [ ];
assert targets.defaultTarget "nixos" "pending" == "pending";
pkgs.runCommandLocal "facter-readiness-test" { } ''touch "$out"''
