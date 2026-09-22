{
  home-manager,
  lib,
  preservation,
  pkgs,
  self,
  targetConfigNames,
  disko,
  nixosTargetEntries,
  nixpkgs,
  formattingCheck,
}:
let
  mkLintCheck =
    name: package: command:
    pkgs.runCommandLocal "${name}-check"
      {
        nativeBuildInputs = [
          package
        ];
        src = self.outPath;
      }
      ''
        cd "$src"
        ${command}
        touch "$out"
      '';

  mkBuildChecks =
    prefix: names: getDerivation:
    lib.listToAttrs (
      map (target: {
        name = "build-${prefix}-${target}";
        value = getDerivation target;
      }) names
    );

  nixosConfigNames = targetConfigNames.nixos or [ ];
  homeConfigNames = targetConfigNames.home or [ ];
  darwinConfigNames = targetConfigNames.darwin or [ ];

  mkEmbeddedHomeManagerCheck =
    entry:
    let
      expectedUsers = lib.optionals (lib.elem "home" entry.config.targets) (
        lib.filter (
          accountName: lib.elem "home" entry.config.accounts.users.${accountName}.targets
        ) entry.config.accountNames
      );
      actualUsers = lib.attrNames self.nixosConfigurations.${entry.name}.config.home-manager.users;
    in
    assert lib.assertMsg (
      actualUsers == expectedUsers
    ) "NixOS target '${entry.name}' embedded Home Manager users do not match Home-eligible accounts";
    pkgs.writeText "embedded-home-manager-${entry.name}" "ok\n";
  embeddedHomeManagerChecks = lib.listToAttrs (
    map (entry: {
      name = "embedded-home-manager-${entry.name}";
      value = mkEmbeddedHomeManagerCheck entry;
    }) nixosTargetEntries
  );
  nonVm = {
    treefmt = formattingCheck;
    deadnix = mkLintCheck "deadnix" pkgs.deadnix "deadnix --fail .";
    statix = mkLintCheck "statix" pkgs.statix "statix check .";
  }
  // embeddedHomeManagerChecks
  // mkBuildChecks "home" homeConfigNames (
    target: self.homeConfigurations.${target}.activationPackage
  )
  // mkBuildChecks "nixos" nixosConfigNames (
    target: self.nixosConfigurations.${target}.config.system.build.toplevel
  )
  // mkBuildChecks "darwin" darwinConfigNames (target: self.darwinConfigurations.${target}.system)
  // (import ./apps/update/tests { inherit lib pkgs; })
  // (import ./apps/build-installer/tests { inherit lib pkgs; })
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    ci-contract = import ./tests/nixos/ci.nix { inherit lib pkgs; };
    installer-runtime = import ./tests/installer/runtime.nix { inherit lib pkgs; };
    installer-iso = import ./tests/installer/iso.nix {
      inherit lib pkgs nixpkgs;
      source = self.outPath;
    };
    installer-fixture = import ./tests/installer/fixture-contract.nix {
      inherit
        lib
        pkgs
        nixpkgs
        disko
        preservation
        ;
    };
    bootstrap = import ./tests/nixos/bootstrap.nix {
      inherit
        lib
        pkgs
        disko
        preservation
        ;
    };
    facter-readiness = import ./tests/nixos/readiness.nix { inherit lib pkgs; };
    impermanence = import ./tests/nixos/impermanence.nix { inherit lib pkgs disko; };
    storage-provisioning = import ./tests/nixos/storage-provisioning.nix { inherit lib pkgs disko; };
    root-device =
      pkgs.runCommandLocal "root-device-test"
        {
          nativeBuildInputs = [
            pkgs.python3
            pkgs.bash
          ];
        }
        ''
          python3 ${./tests/nixos/root-device.py} ${./modules/nixos/features/impermanence/root-device.sh}
          touch "$out"
        '';
  };
  vm = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    installer-e2e = import ./tests/installer/e2e.nix {
      inherit
        lib
        pkgs
        nixpkgs
        disko
        preservation
        ;
    };
    impermanence-vm = import ./tests/nixos/impermanence-vm.nix {
      inherit
        home-manager
        pkgs
        lib
        disko
        preservation
        ;
    };
  };
in
(lib.removeAttrs nonVm [ "treefmt" ])
// vm
// {
  non-vm = pkgs.linkFarm "non-vm-checks" (
    lib.mapAttrsToList (name: path: { inherit name path; }) nonVm
  );
}
