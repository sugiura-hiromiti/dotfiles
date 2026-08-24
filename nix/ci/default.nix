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
  };
  installNix = {
    uses = "cachix/install-nix-action@v31";
  };
in
{
  workflows = {
    ".github/workflows/ci.yml" = {
      name = "CI";

      on = {
        push.branches = [ "main" ];
        pull_request = { };
        workflow_dispatch = { };
      };

      jobs = {
        eval = {
          runs-on = "ubuntu-24.04-arm";

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

        smoke-linux = {
          runs-on = "ubuntu-24.04-arm";
          needs = [ "eval" ];

          steps = [
            checkout
            installNix
            {
              name = "Build representative Linux targets";
              run = ''
                nix build \
                  ".#checks.aarch64-linux.build-nixos-${linuxNixosTarget}" \
                  ".#checks.aarch64-linux.build-home-${linuxHomeTarget}" \
                  --no-write-lock-file
              '';
            }
          ];
        };
      };
    };
    ".github/workflows/drift.yml" = {
      name = "Check drift on generated workflows";
      run = ''
        nix run .#render-workflows
        git diff --exit-code -- .github/workflows
      '';
    };
  };
}
