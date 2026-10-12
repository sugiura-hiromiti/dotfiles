{
  lib,
  pkgs,
}:
let
  installedIdentity = pkgs.writeText "installer-build-machine-identity.json" (
    builtins.toJSON {
      host = "foreign-build-host";
      deployment = "foreign-build-deployment";
    }
  );
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
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.libredirect.hook ];
        BUILD_INSTALLER_APP = app.program;
        BUILD_INSTALLER_UNSAFE_TEMP_APP = unsafeTempApp.program;
        NIX_CONFIG = "experimental-features = nix-command flakes";
        REAL_NIX = lib.getExe pkgs.nix;
        INSTALLER_IDENTITY_REDIRECT = lib.boolToString pkgs.stdenv.hostPlatform.isLinux;
        INSTALLED_IDENTITY = installedIdentity;
        NIX_REDIRECTS = "/etc/dotfiles/identity.json=${installedIdentity}";
      }
      ''
        bash ${./run.sh}
        touch "$out"
      '';
}
