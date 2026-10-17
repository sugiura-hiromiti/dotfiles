{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "dotfiles.deployment-identity-vm";
  requiredFeatures.kvm = false;
  defaults = { lib, modulesPath, ... }: {
    imports = [ (modulesPath + "/profiles/minimal.nix") ];
    nix.enable = true;
    system.switch.enable = true;
    system.tools.nixos-rebuild.enable = true;
    boot = {
      loader = {
        grub = {
          device = lib.mkOverride 5 "nodev";
        };
      };
    };
  };
  nodes = {
    generationA = { nodes, ... }: {
      imports = [
        (import ../../configurations/system-identity.nix {
          targetConfig = {
            host = "test-host";
            deploymentName = "a";
          };
        })
      ];
      virtualisation.additionalPaths = [ nodes.generationB.system.build.toplevel ];
    };
    generationB = {
      imports = [
        (import ../../configurations/system-identity.nix {
          targetConfig = {
            host = "test-host";
            deploymentName = "b";
          };
        })
      ];
    };
  };
  testScript = { nodes, ... }: ''
    import json

    generationA.start()
    generationA.wait_for_console_text("connecting to host...", timeout=900)
    generationA.wait_for_unit("multi-user.target")

    def assert_identity(deployment):
        identity = json.loads(generationA.succeed("cat /etc/dotfiles/identity.json"))
        assert identity == {"host": "test-host", "deployment": deployment}, identity

    with subtest("activate generation A through the system profile"):
        generationA.succeed(
            "nix-env --profile /nix/var/nix/profiles/system "
            "--set ${nodes.generationA.system.build.toplevel}"
        )
        generationA.succeed("/nix/var/nix/profiles/system/bin/switch-to-configuration switch")
        assert_identity("a")

    with subtest("activate generation B"):
        generationA.succeed(
            "nix-env --profile /nix/var/nix/profiles/system "
            "--set ${nodes.generationB.system.build.toplevel}"
        )
        generationA.succeed("/nix/var/nix/profiles/system/bin/switch-to-configuration switch")
        assert_identity("b")

    with subtest("rollback restores generation A identity"):
        # The offline VM has no nixpkgs source for rebuilding nixos-rebuild itself.
        generationA.succeed("nixos-rebuild switch --rollback --no-reexec")
        assert_identity("a")
        generationA.succeed(
            "test $(readlink -f /nix/var/nix/profiles/system) "
            "= ${nodes.generationA.system.build.toplevel}"
        )
  '';
}
