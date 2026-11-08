{
  lib,
  hosts,
  defaultTarget,
  readyNixosTargetEntries,
}:
let
  linuxPlatform = "aarch64-linux";
  checkout = {
    uses = "actions/checkout@v6";
    "with".persist-credentials = false;
  };
  installNix = {
    uses = "cachix/install-nix-action@v31";
    # Evaluating another architecture's NixOS configuration can need built
    # Catppuccin themes through IFD, even when no system is being built.
    "with".extra_nix_config = ''
      extra-substituters = https://catppuccin.cachix.org
      extra-trusted-public-keys = catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU=
    '';
  };
  concurrency = {
    group = "\${{ github.workflow }}-\${{ github.ref }}";
    cancel-in-progress = true;
  };
  nixosEvaluation = lib.concatMapStringsSep "\n" (
    entry:
    "nix eval --no-update-lock-file --raw .#nixosConfigurations.${entry.name}.config.system.build.toplevel.drvPath"
  ) readyNixosTargetEntries;
  # Evaluate the non-VM aggregate with IFD enabled to realize configuration
  # inputs needed by flake check's read-only evaluator. The offline ISO also
  # keeps full derivation closures; instantiate them before that check.
  # Flake check traverses every NixOS configuration, including other systems.
  linuxEvaluation = ''
    nix eval --no-update-lock-file --raw .#checks.${linuxPlatform}.non-vm.drvPath
    nix eval --no-update-lock-file --option allow-import-from-derivation false --raw .#checks.${linuxPlatform}.installer-e2e.drvPath
    ${nixosEvaluation}
    nix flake check --no-build --no-update-lock-file .
  '';
  linuxSteps = [
    checkout
    installNix
    {
      name = "Evaluate";
      run = linuxEvaluation;
    }
    {
      name = "Build non-VM checks";
      run = "nix build --no-update-lock-file --print-build-logs .#checks.${linuxPlatform}.non-vm";
    }
  ];
  darwinTarget = defaultTarget {
    target = "darwin";
    hostName = "aarch64-darwin-a";
  };
  darwinHome = defaultTarget {
    target = "home";
    hostName = "aarch64-darwin-a";
  };
in
{
  useJJ = true;
  defaultValues.jobs.timeout-minutes = 120;
  workflows = {
    ".github/workflows/ci.yml" = {
      name = "CI";
      inherit concurrency;
      permissions.contents = "read";
      on = {
        push.branches = [ "main" ];
        pull_request = { };
        workflow_dispatch = { };
      };
      jobs = {
        linux = {
          runs-on = "ubuntu-24.04-arm";
          steps = linuxSteps;
        };
        darwin = {
          runs-on = "macos-14";
          steps = [
            checkout
            installNix
            {
              name = "Build representative Darwin targets";
              run = "nix build --no-update-lock-file .#checks.${hosts.aarch64-darwin-a.system}.build-darwin-${darwinTarget} .#checks.${hosts.aarch64-darwin-a.system}.build-home-${darwinHome}";
            }
          ];
        };
        generated-workflows = {
          runs-on = "ubuntu-24.04-arm";
          steps = [
            checkout
            installNix
            {
              name = "Check generated workflows";
              run = ''
                nix run --no-update-lock-file .#render-workflows
                git diff --exit-code -- .github/workflows
              '';
            }
          ];
        };
      };
    };
    ".github/workflows/full-build.yml" = {
      name = "Full build";
      inherit concurrency;
      permissions.contents = "read";
      on = {
        schedule = [ { cron = "0 18 * * *"; } ];
        workflow_dispatch = { };
      };
      jobs = {
        linux = {
          runs-on = "ubuntu-24.04-arm";
          steps = linuxSteps;
        };
        darwin = {
          runs-on = "macos-14";
          steps = [
            checkout
            installNix
            {
              name = "Build Darwin checks";
              run = "nix flake check --no-update-lock-file --print-build-logs";
            }
          ];
        };
      };
    };
    ".github/workflows/eval-nix-version.yml" = {
      name = "Nix evaluation compatibility";
      on.pull_request = { };
      jobs.eval-nix-version = {
        runs-on = "ubuntu-24.04-arm";
        strategy = {
          fail-fast = false;
          matrix.nix_version = [
            "2.34.8"
            "2.35.2"
          ];
        };
        steps = [
          checkout
          (
            installNix
            // {
              "with" = installNix."with" // {
                install_url = "https://releases.nixos.org/nix/nix-\${{ matrix.nix_version }}/install";
              };
            }
          )
          {
            name = "Evaluate ready NixOS targets";
            run = linuxEvaluation;
          }
        ];
      };
    };
  };
}
