{
  lib,
  pkgs,
}:
let
  fakeNix = pkgs.writeShellScript "build-installer-fake-nix" (builtins.readFile ./fake-nix.sh);
  fakeMktemp = pkgs.writeShellScript "build-installer-fake-mktemp" (
    builtins.readFile ./fake-mktemp.sh
  );
  app = import ../. {
    inherit lib pkgs;
    nixExecutable = fakeNix;
  };
  unsafeTempApp = import ../. {
    inherit lib pkgs;
    nixExecutable = fakeNix;
    mktempExecutable = fakeMktemp;
  };
in
{
  build-installer-source-staging =
    pkgs.runCommandLocal "build-installer-source-staging-check"
      {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.git
          pkgs.jujutsu
          pkgs.nix
        ];
        BUILD_INSTALLER_APP = app.program;
        BUILD_INSTALLER_UNSAFE_TEMP_APP = unsafeTempApp.program;
        NIX_CONFIG = "experimental-features = nix-command flakes";
        REAL_NIX = lib.getExe pkgs.nix;
      }
      ''
        bash ${./run.sh}
        touch "$out"
      '';
}
