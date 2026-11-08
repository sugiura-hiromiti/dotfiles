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
      readyNixosTargetEntries = [
        {
          name = "arm-target";
          config.system = "aarch64-linux";
        }
        {
          name = "x86-target";
          config.system = "x86_64-linux";
        }
      ];
    })
    workflows
    ;
  commands = job: map (step: step.run) (lib.filter (step: step ? run) job.steps);
  evaluation = ''
    nix eval --no-update-lock-file --raw .#checks.aarch64-linux.non-vm.drvPath
    nix eval --no-update-lock-file --option allow-import-from-derivation false --raw .#checks.aarch64-linux.installer-e2e.drvPath
    nix eval --no-update-lock-file --raw .#nixosConfigurations.arm-target.config.system.build.toplevel.drvPath
    nix eval --no-update-lock-file --raw .#nixosConfigurations.x86-target.config.system.build.toplevel.drvPath
    nix flake check --no-build --no-update-lock-file .
  '';
  universal = [
    evaluation
    "nix build --no-update-lock-file --print-build-logs .#checks.aarch64-linux.non-vm"
  ];
  linuxJobs = [
    workflows.".github/workflows/ci.yml".jobs.linux
    workflows.".github/workflows/full-build.yml".jobs.linux
    workflows.".github/workflows/eval-nix-version.yml".jobs.eval-nix-version
  ];
  hasThemeCache =
    job:
    let
      install = builtins.elemAt job.steps 1;
      nixConfig = install."with".extra_nix_config or "";
    in
    lib.hasInfix "extra-substituters = https://catppuccin.cachix.org" nixConfig
    && lib.hasInfix "extra-trusted-public-keys = catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU=" nixConfig;
in
assert lib.all hasThemeCache linuxJobs;
assert commands workflows.".github/workflows/ci.yml".jobs.linux == universal;
assert commands workflows.".github/workflows/full-build.yml".jobs.linux == universal;
assert
  commands workflows.".github/workflows/eval-nix-version.yml".jobs.eval-nix-version == [ evaluation ];
pkgs.runCommandLocal "ci-contract-test" { } ''touch "$out"''
