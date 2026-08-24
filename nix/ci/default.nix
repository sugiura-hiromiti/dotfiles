{
  hosts,
  lib,
  mkTargetConfigEntries,
}:
let
  defaultTarget =
    target: hostName:
    let
      host = hosts.${hostName};
      matches = lib.filter (
        entry:
        entry.config.host == hostName
        && entry.config.themeName == host.runtime.defaultTheme
        && entry.config.sessionName == host.runtime.defaultSession
        && (target != "home" || entry.config.accountName == host.primaryAccountName)
      ) (mkTargetConfigEntries target);
    in
    assert lib.assertMsg (
      builtins.length matches == 1
    ) "Expected exactly one default ${target} target for ${hostName}";
    (lib.head matches).name;

  linuxHost = "aarch64-linux-a";
  darwinHost = "aarch64-darwin-a";

  linuxNixosTarget = defaultTarget "nixos" linuxHost;
  linuxHomeTarget = defaultTarget "home" linuxHost;

  darwinSystemTarget = defaultTarget "darwin" darwinHost;
  darwinHomeTarget = defaultTarget "home" darwinHost;

  checkout = {
    uses = "actions/checkout@v6";
    "with" = {
      persist-credentials = false;
    };
  };
  installNix = {
    uses = "cachix/install-nix-action@v31";
  };

  linuxRunner = "ubuntu-24.04-arm";
  linuxPlatform = "aarch64-linux";
  darwinRunner = "macos-14";
  darwinPlatform = "aarch64-darwin";
  concurrency = {
    group = "\${{ github.workflow }}-\${{ github.ref }}";
    cancel-in-progress = true;
  };
in
{
  useJJ = true;
  defaultValues = {
    jobs = {
      timeout-minutes = 45;
    };
  };
  workflows = {
    ".github/workflows/full-build.yml" = {
      name = "Full build";
      inherit concurrency;
      permissions = {
        contents = "read";
      };

      on = {
        schedule = [
          {
            # 03:00 JST
            cron = "0 18 * * *";
          }
        ];
        workflow_dispatch = { };
      };
      jobs = {
        linux = {
          runs-on = linuxRunner;

          timeout-minutes = 120;
          steps = [
            checkout
            installNix
            {
              name = "Build all Linux targets";
              run = ''
                nix flake check \
                  --no-write-lock-file \
                  --print-build-logs
              '';
            }
          ];
        };

        darwin = {
          runs-on = darwinRunner;
          timeout-minutes = 120;

          steps = [
            checkout
            installNix
            {
              name = "Build all Darwin targets";
              run = ''
                nix flake check \
                  --no-write-lock-file \
                  --print-build-logs
              '';
            }
          ];
        };
      };
    };
    ".github/workflows/ci.yml" = {
      inherit concurrency;
      name = "CI";
      permissions = {
        contents = "read";
      };
      on = {
        push.branches = [ "main" ];
        pull_request = { };
        workflow_dispatch = { };
      };

      jobs = {
        eval = {
          runs-on = linuxRunner;

          steps = [
            checkout
            installNix
            {
              name = "Evaluate";
              run = ''
                nix flake check \
                  --all-systems \
                  --no-build \
                  --no-write-lock-file
              '';
            }
          ];
        };
        smoke-darwin = {
          runs-on = darwinRunner;
          needs = [
            "eval"
            "lint"
          ];

          steps = [
            checkout
            installNix
            {
              name = "Build representative darwin targets";
              run = ''
                nix build \
                  ".#checks.${darwinPlatform}.build-darwin-${darwinSystemTarget}" \
                  ".#checks.${darwinPlatform}.build-home-${darwinHomeTarget}" \
                  --no-write-lock-file
              '';
            }
          ];
        };
        smoke-linux = {
          runs-on = linuxRunner;
          needs = [
            "eval"
            "lint"
          ];

          steps = [
            checkout
            installNix
            {
              name = "Build representative Linux targets";
              run = ''
                nix build \
                  ".#checks.${linuxPlatform}.build-nixos-${linuxNixosTarget}" \
                  ".#checks.${linuxPlatform}.build-home-${linuxHomeTarget}" \
                  --no-write-lock-file
              '';
            }
          ];
        };
        lint = {
          runs-on = linuxRunner;
          steps = [
            checkout
            installNix
            {
              name = "Deadnix";
              run = "nix build .#checks.${linuxPlatform}.deadnix --no-write-lock-file";
            }

            {
              name = "Statix";
              run = "nix build .#checks.${linuxPlatform}.statix --no-write-lock-file";
            }

            {
              name = "Treefmt";
              run = "nix fmt -- --ci";
            }
            {
              name = "Check generated workflows";
              run = ''
                nix run .#render-workflows
                git diff --exit-code -- .github/workflows
              '';
            }
          ];
        };
      };
    };
  };
}
