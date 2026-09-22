{
  lib,
  pkgs,
  nixpkgs,
  disko,
  preservation,
}:
let
  fixture = import ./fixture.nix {
    inherit
      lib
      pkgs
      nixpkgs
      disko
      preservation
      ;
  };
  sourceClosure = pkgs.closureInfo { rootPaths = [ fixture.source ]; };
  expectedMetadata = pkgs.writeText "installer-fixture-metadata.json" (
    builtins.toJSON {
      primaryUser = {
        name = "operator";
        home = "/srv/operator";
        uid = 1441;
        group = "operators";
        gid = 1442;
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        hashedPasswordFile = "/persist/etc/dotfiles/password-operator.hash";
      };
      sudoEnabled = true;
      mutableUsers = false;
      boot = {
        systemdBoot = true;
        canTouchEfiVariables = false;
        inherit (fixture) efiArch;
      };
      preservation = {
        runtimePath = "/srv/operator/dotfiles";
        backingPath = "/persist/srv/operator/dotfiles";
      };
    }
  );
in
pkgs.runCommandLocal "installer-fixture-contract"
  {
    nativeBuildInputs = [
      pkgs.nix
      pkgs.jq
    ];
  }
  ''
    # Evaluate the generated flake with Nix itself, after its source is built.
    # A private store keeps this offline and avoids import-from-derivation
    # during the enclosing flake's evaluation.
    export NIX_REMOTE="local?root=$TMPDIR/nix"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    export NIX_CONFIG="experimental-features = nix-command flakes
    substituters =
    build-users-group =
    allow-import-from-derivation = false
    "
    mkdir -p "$TMPDIR/nix/nix/store"
    while IFS= read -r path; do
      cp -a "$path" "$TMPDIR/nix/nix/store/"
    done < ${sourceClosure}/store-paths
    nix-store --load-db < ${sourceClosure}/registration

    frozen=(--offline --no-update-lock-file --no-write-lock-file)
    nix flake metadata "''${frozen[@]}" --json path:${fixture.source} > flake-metadata.json
    jq -e --slurpfile lock ${fixture.source}/flake.lock \
      '.locks == $lock[0]' flake-metadata.json

    nix eval "''${frozen[@]}" --json \
      path:${fixture.source}#nixosConfigurations.${fixture.target} \
      --apply 'configuration: {
        metadata = configuration.config.dotfiles.installer.metadata;
        facterPath = toString configuration.config.hardware.facter.reportPath;
        facterExists = builtins.pathExists configuration.config.hardware.facter.reportPath;
        diskoDrvPath = configuration.config.system.build.diskoScript.drvPath;
      }' > configuration.json
    jq -e --slurpfile expected ${expectedMetadata} \
      --arg facterPath "$(jq -r .path flake-metadata.json)/${fixture.facterRelativePath}" '
      .metadata == $expected[0] and
      .facterExists and .facterPath == $facterPath and
      (.diskoDrvPath | test("^/nix/store/[a-z0-9]{32}-.+\\.drv$"))
    ' configuration.json
    diskoDrvPath=$(jq -r .diskoDrvPath configuration.json)
    test "$(nix-store --query --binding system "$diskoDrvPath")" = ${lib.escapeShellArg fixture.system}
    nix-store --query --outputs "$diskoDrvPath" > disko-outputs
    test "$(wc -l < disko-outputs)" -eq 1
    grep -Eq '^/nix/store/[a-z0-9]{32}-.+$' disko-outputs

    mkdir "$out"
    cp flake-metadata.json configuration.json disko-outputs "$out/"
  ''
