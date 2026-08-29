{
  lib,
  pkgs,
  self,
  targetConfigNames,
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

  emacsInitAnvil =
    pkgs.runCommandLocal "emacs-init-anvil-check"
      {
        nativeBuildInputs = [ pkgs.emacs ];
        src = self.outPath;
      }
      ''
        cd "$src"
        emacs --batch -Q \
          -l nix/modules/home/programs/emacs/config/test/init-anvil-test.el \
          -f ert-run-tests-batch-and-exit
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
in
{
  deadnix = mkLintCheck "deadnix" pkgs.deadnix "deadnix --fail .";
  emacs-init-anvil = emacsInitAnvil;
  statix = mkLintCheck "statix" pkgs.statix "statix check .";
}
// mkBuildChecks "home" homeConfigNames (
  target: self.homeConfigurations.${target}.activationPackage
)
// mkBuildChecks "nixos" nixosConfigNames (
  target: self.nixosConfigurations.${target}.config.system.build.toplevel
)
// mkBuildChecks "darwin" darwinConfigNames (target: self.darwinConfigurations.${target}.system)
// (import ./apps/update/tests { inherit lib pkgs; })
