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

  mkEvalCheck =
    name: drvPath:
    pkgs.writeText "eval-${name}" ''
      ${builtins.unsafeDiscardStringContext (toString drvPath)}
    '';

  mkEvalChecks =
    prefix: names: getDrvPath:
    lib.listToAttrs (
      map (host: {
        name = "eval-${prefix}-${host}";
        value = mkEvalCheck "${prefix}-${host}" (getDrvPath host);
      }) names
    );

  nixosConfigNames = targetConfigNames.nixos or [ ];
  homeConfigNames = targetConfigNames.home or [ ];
  darwinConfigNames = targetConfigNames.darwin or [ ];
in
{
  deadnix = mkLintCheck "deadnix" pkgs.deadnix "deadnix --no-lambda-pattern-names --fail .";
  statix = mkLintCheck "statix" pkgs.statix "statix check .";
}
// mkEvalChecks "home" homeConfigNames (
  host: self.homeConfigurations.${host}.activationPackage.drvPath
)
// mkEvalChecks "nixos" nixosConfigNames (
  host: self.nixosConfigurations.${host}.config.system.build.toplevel.drvPath
)
// mkEvalChecks "darwin" darwinConfigNames (host: self.darwinConfigurations.${host}.system.drvPath)
