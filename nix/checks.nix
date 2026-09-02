{
  home-manager,
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

  fakeAnvilEmacs = pkgs.writeShellScriptBin "emacsclient" ''
    printf '%s\n' '"eyJqc29ucnBjIjoiMi4wIiwiaWQiOjEsInJlc3VsdCI6e319"'
  '';

  mkAnvilHomeFiles =
    aiToolsEnabled: emacsEnabled:
    (home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./modules/home/base/paths.nix
        ./modules/home/features/ai-tools/anvil.nix
        ./modules/home/programs/emacs
        (
          { lib, ... }:
          {
            options.dotfiles.features.aiTools.enable = lib.mkEnableOption "AI-assisted development tools";

            config = {
              home = {
                username = "anvil-test";
                homeDirectory = "/home/anvil-test";
                stateVersion = "26.05";
              };
              programs.emacs.package = fakeAnvilEmacs;
              services.emacs.enable = false;
              xdg.enable = true;
              dotfiles = {
                features.aiTools.enable = aiToolsEnabled;
                programs.emacs.enable = emacsEnabled;
              };
            };
          }
        )
      ];
    }).config.home-files;
  emacsAnvilHomeFiles =
    let
      disabledHomeFiles = [
        (mkAnvilHomeFiles false false)
        (mkAnvilHomeFiles false true)
        (mkAnvilHomeFiles true false)
      ];
      enabledHomeFiles = mkAnvilHomeFiles true true;
      initPath = ".config/emacs/lisp/init-anvil.el";
      bridgePath = ".config/emacs/anvil-stdio.sh";
    in
    pkgs.runCommandLocal "emacs-anvil-home-files-check" { } ''
      for homeFiles in ${lib.escapeShellArgs (map toString disabledHomeFiles)}; do
        for path in \
          "$homeFiles/${initPath}" \
          "$homeFiles/${bridgePath}"
        do
          test ! -e "$path"
          test ! -L "$path"
        done
      done

      enabledHomeFiles=${lib.escapeShellArg (toString enabledHomeFiles)}
      test -f "$enabledHomeFiles/${initPath}"
      test -f "$enabledHomeFiles/${bridgePath}"
      test -x "$enabledHomeFiles/${bridgePath}"

      response="$({
        export PATH=/path-that-does-not-exist
        printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"test"}' \
          | "$enabledHomeFiles/${bridgePath}" --server-id=anvil
      })"
      test "$response" = '{"jsonrpc":"2.0","id":1,"result":{}}'

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
  emacs-anvil-home-files = emacsAnvilHomeFiles;
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
