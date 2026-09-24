{ lib, pkgs }:
let
  runtimeContexts = import ../../runtime-contexts.nix;
  registry = import ../../lib/hosts.nix {
    inherit lib runtimeContexts;
    hostDir = ../../profiles/hosts;
  };
  targets = import ../../lib/targets.nix {
    inherit lib;
    inherit (registry) hosts hostNames;
    runtime = import ../../lib/runtime.nix { inherit lib runtimeContexts; };
    targetNames = import ../../lib/target-names.nix { inherit lib; };
  };
  inherit
    (import ../../ci {
      inherit lib;
      inherit (registry) hosts;
      inherit (targets) defaultTarget;
      readyNixosTargetEntries = [ ];
    })
    workflows
    ;
  commands = job: map (step: step.run) (lib.filter (step: step ? run) job.steps);
  evaluation = ''
    nix eval --no-update-lock-file --option allow-import-from-derivation false --raw .#checks.aarch64-linux.installer-e2e.drvPath
    nix flake check --no-build --no-update-lock-file .
  '';
  universal = [
    evaluation
    "nix build --no-update-lock-file --print-build-logs .#checks.aarch64-linux.non-vm"
  ];
in
assert commands workflows.".github/workflows/ci.yml".jobs.linux == universal;
assert commands workflows.".github/workflows/full-build.yml".jobs.linux == universal;
assert
  commands workflows.".github/workflows/eval-nix-version.yml".jobs.eval-nix-version == [ evaluation ];
pkgs.runCommandLocal "ci-contract-test" { } ''touch "$out"''
