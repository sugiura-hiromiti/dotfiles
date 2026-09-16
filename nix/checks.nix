{
  lib,
  preservation,
  pkgs,
  self,
  targetConfigNames,
  disko,
  nixosTargetEntries,
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
in
{
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
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
  preservation = import ./tests/nixos/preservation.nix { inherit pkgs preservation; };
  ephemeral-root = import ./tests/nixos/ephemeral-root.nix { inherit pkgs lib disko; };
  impermanence = import ./tests/nixos/impermanence.nix { inherit lib disko pkgs; };
  storage-provisioning = import ./tests/nixos/storage-provisioning.nix { inherit lib pkgs disko; };
  storage-provisioning-vm = import ./tests/nixos/storage-provisioning-vm.nix {
    inherit lib pkgs disko;
  };
  impermanence-vm = import ./tests/nixos/impermanence-vm.nix {
    inherit
      pkgs
      lib
      disko
      preservation
      ;
  };
}
