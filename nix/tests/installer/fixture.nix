{
  lib,
  pkgs,
  nixpkgs,
  disko,
  preservation,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  efiArch = lib.toUpper pkgs.stdenv.hostPlatform.efiArch;
  facterRelativePath = "nix/profiles/hosts/e2e/facter.json";
  seedReport = ./facter.json;
  seedTarget = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      (import ../../configurations/nixos-bootstrap.nix {
        inherit disko preservation;
        hostConfig = {
          accounts.primary = "operator";
          facterPath = seedReport;
        };
      })
      ./target.nix
    ];
  };
  mkPathInput = input: {
    locked = {
      lastModified = 0;
      inherit (input) narHash;
      path = toString input;
      type = "path";
    };
    original = {
      path = toString input;
      type = "path";
    };
  };
  fixtureLock = {
    nodes = {
      root.inputs = {
        nixpkgs = "nixpkgs";
        disko = "disko";
        preservation = "preservation";
      };
      nixpkgs = mkPathInput nixpkgs;
      disko = (mkPathInput disko) // {
        inputs.nixpkgs = [ "nixpkgs" ];
      };
      preservation = mkPathInput preservation;
    };
    root = "root";
    version = 7;
  };
  fixtureLockFile = pkgs.writeText "e2e-flake.lock" (builtins.toJSON fixtureLock);
  # Locked store-path inputs reuse the check's pinned module sources without a
  # second network graph, while remaining valid under pure flake evaluation.
  fixtureFlake = pkgs.writeText "e2e-flake.nix" ''
    {
      inputs = {
        nixpkgs.url = "path:${nixpkgs}";
        disko = {
          url = "path:${disko}";
          inputs.nixpkgs.follows = "nixpkgs";
        };
        preservation.url = "path:${preservation}";
      };
      outputs = { self, nixpkgs, disko, preservation }: {
        nixosConfigurations.e2e = nixpkgs.lib.nixosSystem {
          system = "${system}";
          modules = [
            (import ./nix/configurations/nixos-bootstrap.nix {
              inherit disko preservation;
              hostConfig = {
                accounts.primary = "operator";
                facterPath = self + "/${facterRelativePath}";
              };
            })
            ./target.nix
          ];
        };
      };
    }
  '';
  source = pkgs.runCommand "dotfiles-installer-e2e-source" { } ''
    mkdir -p "$out/nix/configurations" "$out/nix/modules/nixos/features" "$out/nix/profiles/hosts/e2e"
    cp ${fixtureFlake} "$out/flake.nix"
    cp ${fixtureLockFile} "$out/flake.lock"
    cp ${../../configurations/nixos-bootstrap.nix} "$out/nix/configurations/nixos-bootstrap.nix"
    cp -R ${../../modules/nixos/features/storage} "$out/nix/modules/nixos/features/storage"
    cp -R ${../../modules/nixos/features/impermanence} "$out/nix/modules/nixos/features/impermanence"
    cp ${./target.nix} "$out/target.nix"
    cp ${seedReport} "$out/${facterRelativePath}"
    printf '#!/bin/sh\nexit 0\n' > "$out/executable-probe"
    chmod +x "$out/executable-probe"
    ln -s executable-probe "$out/symlink-probe"
  '';
in
{
  inherit
    system
    efiArch
    facterRelativePath
    seedReport
    seedTarget
    source
    fixtureLock
    ;
  host = "e2e";
  target = "e2e";
  primaryAccount = "operator";
}
