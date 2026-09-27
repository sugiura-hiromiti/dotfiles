{
  lib,
  pkgs,
}:
let
  mkUpdateScript = import ../script.nix { inherit lib pkgs; };
  fixtureSource = pkgs.runCommandLocal "update-source-fixture" { } ''
    mkdir -p "$out"
    printf '%s\n' L0 > "$out/flake.lock"
    printf '%s\n' S0 > "$out/source-marker"
  '';
  fixturePostPreflightBarrier = pkgs.writeShellScript "update-test-post-preflight-barrier" ''
    set -eu
    if [ "''${TEST_BLOCK_AFTER_PREFLIGHT:-0}" = 1 ]; then
      : > "''${TEST_STATE:?TEST_STATE is required}/after-preflight-waiting"
      while [ ! -e "$TEST_STATE/release-after-preflight" ]; do
        ${lib.getExe' pkgs.coreutils "sleep"} 0.05
      done
    fi
  '';
  fakeNix = pkgs.writeShellScriptBin "nix" (builtins.readFile ./fake-nix.sh);
  launcherNix = pkgs.writeShellScriptBin "nix" ''
    set -eu

    state="''${LAUNCHER_STATE:?LAUNCHER_STATE is required}"
    mkdir -p "$state"
    printf '%s\n' "$@" > "$state/args"

    no_write_lock=0
    for argument in "$@"; do
      if [ "$argument" = --no-write-lock-file ]; then
        no_write_lock=1
      fi
    done
    if [ "$no_write_lock" -eq 0 ]; then
      printf '%s\n' launcher-sentinel > flake.lock
    fi

    exit 29
  '';
  launcherSudo = pkgs.writeShellScriptBin "sudo" ''
    set -eu

    if [ "$#" -ne 1 ] || [ "$1" != -v ]; then
      printf '%s\n' 'unexpected sudo invocation' >&2
      exit 64
    fi
  '';
  launcherBin = pkgs.symlinkJoin {
    name = "update-launcher-test-bin";
    paths = [
      launcherNix
      launcherSudo
    ];
  };
  launcherOsRelease = pkgs.writeText "update-launcher-test-os-release" ''
    NAME=NixOS
    ID=nixos
    PRETTY_NAME="NixOS"
  '';

  fixtureOperationApp = pkgs.writeTextFile {
    name = "dotfiles-operation-test";
    executable = true;
    text = ''
      #!${lib.getExe pkgs.nushell} --no-config-file
      const SOURCE = "${fixtureSource}"
      const GIT = "${lib.getExe pkgs.git}"
      const MKDIR = "${lib.getExe' pkgs.coreutils "mkdir"}"
      ${builtins.readFile ../operation.nu}
      let targets = [
        {
          name: "home-test"
          eval: "homeConfigurations.home-test.activationPackage.drvPath"
          authorize: []
          switch: ["nix" "run" "nixpkgs#home-manager" "--" "switch" "--flake"]
        }
        {
          name: "home-test-second"
          eval: "homeConfigurations.home-test-second.activationPackage.drvPath"
          authorize: []
          switch: ["nix" "run" "nixpkgs#home-manager" "--" "switch" "--flake"]
        }
      ]
      run-operation (pwd | path expand --strict) $SOURCE $targets
    '';
  };
  fixturePlan = pkgs.writeText "update-plan-fixture.json" (
    builtins.toJSON {
      aliases.test = "test";
      defaultHosts.tester = "test";
      themeByHour = lib.genAttrs (map (hour: if hour < 10 then "0${toString hour}" else toString hour) (
        lib.range 0 23
      )) (_: "dark");
      hosts.test = {
        deployments = [ ];
        defaultDeployment = null;
        autoSession = {
          gui = "tty";
          tty = "tty";
        };
        defaultSession = "tty";
        home.tester.dark.tty = {
          name = "home-test";
          eval = "homeConfigurations.home-test.activationPackage.drvPath";
          authorize = [ (toString fixturePostPreflightBarrier) ];
          switch = [
            "nix"
            "run"
            "nixpkgs#home-manager"
            "--"
            "switch"
            "--flake"
          ];
        };
        system = null;
      };
    }
  );
  fixtureApp = mkUpdateScript {
    source = fixtureSource;
    planFile = fixturePlan;
    identityPath = "identity.json";
  };

  fixtureSystemTarget = deployment: session: ready: {
    name = "nixos-${deployment}-${session}-test";
    eval = "nixosConfigurations.nixos-${deployment}-${session}-test.config.system.build.toplevel.drvPath";
    inherit ready;
    authorize = [ ];
    # Reuse fake activation to test selection without switching the test machine.
    switch = [
      "nix"
      "run"
      "nixpkgs#home-manager"
      "--"
      "switch"
      "--flake"
    ];
  };
  fixtureSystemHost = {
    deployments = [
      "parallels"
      "qemu"
      "pending"
    ];
    defaultDeployment = "parallels";
    autoSession = {
      gui = "tty";
      tty = "tty";
    };
    defaultSession = "gui";
    # A Home target exists so readiness regressions cannot hide behind a missing Home.
    home.tester.dark.tty = fixtureSystemTarget "home" "tty" true;
    system = {
      kind = "nixos";
      targets = lib.genAttrs [ "parallels" "qemu" "pending" ] (deployment: {
        dark = lib.genAttrs [ "gui" "tty" ] (
          session: fixtureSystemTarget deployment session (deployment != "pending")
        );
      });
    };
  };
  fixtureNixosPlan = pkgs.writeText "update-nixos-plan-fixture.json" (
    builtins.toJSON {
      aliases = {
        test = "test";
        logical-test = "test";
        other = "other";
        nodefault = "nodefault";
      };
      defaultHosts.tester = "test";

      themeByHour = lib.genAttrs (map (hour: if hour < 10 then "0${toString hour}" else toString hour) (
        lib.range 0 23
      )) (_: "dark");

      hosts = {
        test = fixtureSystemHost;
        other = fixtureSystemHost;
        nodefault = fixtureSystemHost // {
          defaultDeployment = null;
        };
      };
    }
  );
  fixtureNativeNixosApp = mkUpdateScript {
    source = fixtureSource;
    planFile = fixtureNixosPlan;
    identityPath = "identity.json";
  };
  fixtureNixosApp = pkgs.runCommandLocal "update-nixos-fixture-runtime" { } ''
    # Linux exercises the native detector through libredirect. Darwin simulates
    # the same NixOS environment without changing the production script.
    ${
      if pkgs.stdenv.hostPlatform.isLinux then
        "cp ${fixtureNativeNixosApp} \"$out\""
      else
        ''
          substitute ${fixtureNativeNixosApp} "$out" \
            --replace-fail '$nu.os-info.name == "macos"' 'false' \
            --replace-fail '$nu.os-info.name == "linux"' 'true' \
            --replace-fail '/etc/os-release' '${launcherOsRelease}'
        ''
    }
    chmod +x "$out"
  '';
  generatedPlan =
    kind:
    (import ../plan.nix {
      inherit lib;
      system = "test-system";
      hostNames = [ "logical-test" ];
      hosts.logical-test = {
        system = "test-system";
        targetHost = "test";
        matchNames = [
          "logical-test"
          "test"
        ];
        runtime = {
          defaultSession = "tty";
          targetAxes.session = false;
        };
        primaryAccountName = "tester";
        systemTargetKind = kind;
        deploymentNames = [
          "parallels"
          "qemu"
        ];
        defaultDeploymentName = "parallels";
      };
      mkTargetConfigEntries =
        target:
        if target == kind then
          map
            (deployment: {
              name = "test--deployment-${deployment}";
              config = {
                system = "test-system";
                targetHost = "test";
                deploymentName = deployment;
                themeName = "dark";
                sessionName = "tty";
              }
              // lib.optionalAttrs (kind == "nixos") { facterReady = deployment == "parallels"; };
            })
            [
              "parallels"
              "qemu"
            ]
        else if target == "home" then
          [
            {
              name = "test--account-tester";
              config = {
                system = "test-system";
                targetHost = "test";
                accountName = "tester";
                themeName = "dark";
                sessionName = "tty";
              };
            }
          ]
        else
          [ ];
    }).data;
  generatedNixosPlan = generatedPlan "nixos";
  generatedDarwinPlan = generatedPlan "darwin";
in
assert generatedNixosPlan.aliases.logical-test == "test";
assert
  generatedNixosPlan.hosts.test.deployments == [
    "parallels"
    "qemu"
  ];
assert generatedNixosPlan.hosts.test.defaultDeployment == "parallels";
assert generatedNixosPlan.hosts.test.system.targets.parallels.dark.tty.ready;
assert !generatedNixosPlan.hosts.test.system.targets.qemu.dark.tty.ready;
assert generatedNixosPlan.hosts.test.home.tester.dark.tty.name == "test--account-tester";
assert generatedDarwinPlan.hosts.test.system.targets.qemu.dark.tty.ready;
{
  update-source-pin = pkgs.runCommandLocal "update-source-pin-check" { } ''
    grep -F 'const SOURCE = "${fixtureSource}"' ${fixtureApp}
    grep -F 'const PLAN = "${fixturePlan}"' ${fixtureApp}
    touch "$out"
  '';

  update-operation-consistency =
    pkgs.runCommandLocal "update-operation-consistency-check"
      {
        nativeBuildInputs = [
          fakeNix
          pkgs.bash
          pkgs.coreutils
          pkgs.git
          pkgs.nushell
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.libredirect.hook ];
        UPDATE_APP = toString fixtureApp;
        UPDATE_NIXOS_APP = toString fixtureNixosApp;
        OPERATION_APP = toString fixtureOperationApp;
        NIX_REDIRECTS = "/etc/os-release=${launcherOsRelease}";
      }
      ''
        export PATH="${fakeNix}/bin:$PATH"
        bash ${./run.sh}
        touch "$out"
      '';

  update-launcher-lock-safety =
    pkgs.runCommandLocal "update-launcher-lock-safety-check"
      (
        {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.nushell
          ]
          ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.libredirect.hook ];
          LAUNCHER_BIN = launcherBin;
          LAUNCHER_CONFIG = ../../../modules/home/programs/nushell/config/config.nu;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          NIX_REDIRECTS = "/etc/os-release=${launcherOsRelease}";
        }
      )
      ''
        bash ${./launcher.sh}
        touch "$out"
      '';
}
