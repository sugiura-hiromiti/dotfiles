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
  invalidRegistry = hostDir: import ../../lib/hosts.nix { inherit lib runtimeContexts hostDir; };
  names = entries: map (entry: entry.name) entries;
  forHost = host: entries: lib.filter (entry: entry.config.host == host) entries;
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  production = import ../../lib/hosts.nix {
    inherit lib runtimeContexts;
    hostDir = ../../profiles/hosts;
  };
  productionTargets = import ../../lib/targets.nix {
    inherit lib;
    inherit (production) hosts hostNames;
    runtime = import ../../lib/runtime.nix { inherit lib runtimeContexts; };
    targetNames = import ../../lib/target-names.nix { inherit lib; };
  };
in
assert
  registry.facterRelativePath "pending" "vm"
  == "nix/profiles/hosts/pending/deployments/vm/facter.json";
assert !registry.hosts.pending.deployments.vm.facterReady;
assert registry.hosts.ready.deployments.vm.facterReady;
assert !registry.hosts.multi.deployments.pending.facterReady;
assert registry.hosts.multi.deployments.ready.facterReady;
assert !(registry.hosts.multi ? facterPath);
assert !(registry.hosts.darwin-multi.deployments.first ? facterReady);
assert names (forHost "pending" targets.declaredNixosTargetEntries) == [ "pending--deployment-vm" ];
assert names (forHost "ready" targets.readyNixosTargetEntries) == [ "ready--deployment-vm" ];
assert forHost "pending" targets.readyNixosTargetEntries == [ ];
assert builtins.length (forHost "multi" targets.declaredNixosTargetEntries) == 8;
assert builtins.length (forHost "multi" (targets.mkTargetConfigEntries "home")) == 4;
assert
  names (forHost "multi" targets.readyNixosTargetEntries) == [
    "multi--deployment-ready--theme-dark--session-tty"
    "multi--deployment-ready--theme-dark--session-gui"
    "multi--deployment-ready--theme-light--session-tty"
    "multi--deployment-ready--theme-light--session-gui"
  ];
assert
  names (targets.mkReadyTargetConfigEntries "darwin") == [
    "darwin-multi--deployment-first"
    "darwin-multi--deployment-second"
  ];
assert
  map (host: host.host) (targets.declaredNixosHostsForSystem "aarch64-linux") == [
    "multi"
    "pending"
    "ready"
  ];
assert targets.declaredNixosHostsForSystem "x86_64-linux" == [ ];
assert
  targets.defaultTarget {
    target = "nixos";
    hostName = "pending";
  } == "pending--deployment-vm";
assert
  targets.defaultTarget {
    target = "nixos";
    hostName = "multi";
    deploymentName = "ready";
  } == "multi--deployment-ready--theme-dark--session-tty";
assert
  targets.defaultTarget {
    target = "home";
    hostName = "multi";
  } == "multi--account-admin--theme-dark--session-tty";
assert fails (
  targets.defaultTarget {
    target = "nixos";
    hostName = "multi";
  }
);
assert fails (invalidRegistry ../fixtures/invalid-hosts/no-deployments).hosts.bad;
assert fails (invalidRegistry ../fixtures/invalid-hosts/bad-default).hosts.bad;
assert production.hosts.aarch64-linux-a.defaultDeploymentName == "parallels";
assert production.hosts.aarch64-linux-a.deployments.parallels.facterReady;
assert !production.hosts.aarch64-linux-a.deployments.qemu.facterReady;
assert lib.elem "aarch64-linux-a--deployment-qemu--theme-dark--session-gui" (
  names productionTargets.declaredNixosTargetEntries
);
assert
  !(lib.any (entry: entry.config.deploymentName == "qemu") productionTargets.readyNixosTargetEntries);
pkgs.runCommandLocal "facter-readiness-test" { } ''touch "$out"''
