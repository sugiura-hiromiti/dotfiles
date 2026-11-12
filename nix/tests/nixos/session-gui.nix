{ lib, pkgs }:
let
  primary = "session-test";
  evaluate =
    feature: extra:
    (lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      specialArgs.accounts.primary = primary;
      modules = [
        ../../modules/nixos/features/session-gui.nix
        {
          boot.isContainer = true;
          system.stateVersion = "26.05";
          users.users.${primary}.isNormalUser = true;
          dotfiles.features.sessionGui = feature;
        }
        extra
      ];
    }).config;

  contains = package: packages: lib.elem (toString package) (map toString packages);
  passesAssertions = config: lib.all (entry: entry.assertion) config.assertions;
  failsAssertion =
    option: config:
    let
      # Evaluate every assertion, even if an earlier one already failed.
      failures = map (entry: if entry.assertion then null else entry.message) config.assertions;
    in
    builtins.deepSeq failures (
      lib.any (message: message != null && lib.hasInfix option message) failures
    );

  enabled = evaluate { enable = true; } { };
  disabled = evaluate { } { };
  withoutGreeter = evaluate {
    enable = true;
    greeter.enable = false;
  } { };
  tuigreet = evaluate {
    enable = true;
    greeter.backend = "tuigreet";
  } { };

  customNiri = pkgs.niri.overrideAttrs { pname = "session-test-niri"; };
  customTuigreet = pkgs.tuigreet.overrideAttrs { pname = "session-test-tuigreet"; };
  customized =
    evaluate
      {
        enable = true;
        session = "niri";
        greeter = {
          backend = "tuigreet";
          tuigreet = {
            package = customTuigreet;
            user = "custom-greeter";
          };
        };
      }
      {
        programs.niri.package = customNiri;
        users.users.custom-greeter = {
          isSystemUser = true;
          group = "greeter";
        };
      };

  externallyEnabled = evaluate { } {
    programs.niri.enable = true;
    programs.xwayland.enable = true;
    services.displayManager.noctalia-greeter.enable = true;
  };
  externalGreeter =
    evaluate
      {
        enable = true;
        greeter.enable = false;
      }
      {
        services.greetd = {
          enable = true;
          settings.default_session.command = "external-greeter";
        };
        programs.xwayland.enable = true;
      };

  disabledNiri = evaluate { enable = true; } {
    programs.niri.enable = lib.mkForce false;
  };
  missingSession =
    evaluate
      {
        enable = true;
        greeter.enable = false;
      }
      {
        services.displayManager.sessionPackages = lib.mkForce [ ];
      };
  disabledNoctalia = evaluate { enable = true; } {
    services.displayManager.noctalia-greeter.enable = lib.mkForce false;
  };
  disabledGreetd = evaluate { enable = true; } {
    services.greetd.enable = lib.mkForce false;
    # Upstream Noctalia reads this even when greetd is disabled, while greetd
    # only supplies its default user when enabled. Keep that independent input
    # valid so every assertion, including our Greeter contract, is evaluated.
    services.greetd.settings.default_session.user = primary;
  };
  disabledTuigreet =
    evaluate
      {
        enable = true;
        greeter.backend = "tuigreet";
      }
      {
        services.greetd.enable = lib.mkForce false;
      };
  missingTuigreetUser = evaluate {
    enable = true;
    greeter = {
      backend = "tuigreet";
      tuigreet.user = "missing-greeter";
    };
  } { };
  disabledSessionDiscovery = evaluate { enable = true; } {
    services.displayManager.enable = lib.mkForce false;
  };
  wrongNoctaliaSession = evaluate { enable = true; } {
    services.displayManager.noctalia-greeter.settings.session.default = lib.mkForce "other-session";
  };
  wrongTuigreetCommand =
    evaluate
      {
        enable = true;
        greeter.backend = "tuigreet";
      }
      {
        services.greetd.settings.default_session.command = lib.mkForce "other-session";
      };
  wrongNoctaliaCommand = evaluate { enable = true; } {
    services.greetd.settings.default_session.command = lib.mkForce "other-greeter";
  };
  unsupportedSession =
    builtins.tryEval
      (evaluate {
        enable = true;
        session = "unsupported-session";
      } { }).dotfiles.features.sessionGui.session;
in
# Positive projections force NixOS assertions, not only the options under test.
assert lib.all passesAssertions [
  enabled
  disabled
  withoutGreeter
  tuigreet
  customized
  externallyEnabled
  externalGreeter
];
assert !disabled.programs.niri.enable;
assert !disabled.services.greetd.enable;
assert !disabled.services.displayManager.noctalia-greeter.enable;
assert !disabled.services.accounts-daemon.enable;
assert disabled.services.displayManager.noctalia-greeter.passwordlessSyncUsers == [ ];
assert !contains pkgs.tuigreet disabled.environment.systemPackages;
assert enabled.programs.niri.enable;
assert contains enabled.programs.niri.package enabled.services.displayManager.sessionPackages;
assert lib.elem "niri" enabled.services.displayManager.sessionData.sessionNames;
assert enabled.services.displayManager.noctalia-greeter.enable;
assert enabled.services.displayManager.noctalia-greeter.settings.session.default == "niri";
assert enabled.services.displayManager.noctalia-greeter.passwordlessSyncUsers == [ primary ];
assert enabled.services.accounts-daemon.enable;
assert !enabled.programs.xwayland.enable;
assert enabled.specialisation == { };
assert withoutGreeter.programs.niri.enable;
assert contains withoutGreeter.programs.niri.package
  withoutGreeter.services.displayManager.sessionPackages;
assert !withoutGreeter.services.greetd.enable;
assert !withoutGreeter.services.displayManager.noctalia-greeter.enable;
assert !withoutGreeter.services.accounts-daemon.enable;
assert withoutGreeter.services.displayManager.noctalia-greeter.passwordlessSyncUsers == [ ];
assert tuigreet.services.greetd.enable;
assert tuigreet.services.greetd.useTextGreeter;
assert !tuigreet.services.displayManager.noctalia-greeter.enable;
assert !tuigreet.services.accounts-daemon.enable;
assert tuigreet.services.greetd.settings.default_session.user == "greeter";
assert
  tuigreet.services.greetd.settings.default_session.command
  == "${pkgs.tuigreet}/bin/tuigreet --remember --cmd ${pkgs.niri}/bin/niri-session";
assert contains customNiri customized.services.displayManager.sessionPackages;
assert contains customTuigreet customized.environment.systemPackages;
assert customized.services.greetd.settings.default_session.user == "custom-greeter";
assert
  customized.services.greetd.settings.default_session.command
  == "${customTuigreet}/bin/tuigreet --remember --cmd ${customNiri}/bin/niri-session";
assert externallyEnabled.programs.niri.enable;
assert externallyEnabled.programs.xwayland.enable;
assert externallyEnabled.services.displayManager.noctalia-greeter.enable;
assert externallyEnabled.services.displayManager.noctalia-greeter.passwordlessSyncUsers == [ ];
assert externalGreeter.services.greetd.enable;
assert externalGreeter.services.greetd.settings.default_session.command == "external-greeter";
assert externalGreeter.programs.xwayland.enable;
assert failsAssertion "dotfiles.features.sessionGui.session" disabledNiri;
assert failsAssertion "dotfiles.features.sessionGui.session" missingSession;
assert failsAssertion "dotfiles.features.sessionGui.greeter" disabledNoctalia;
assert failsAssertion "dotfiles.features.sessionGui.greeter" disabledGreetd;
assert failsAssertion "dotfiles.features.sessionGui.greeter" disabledTuigreet;
assert lib.assertMsg
  (failsAssertion "dotfiles.features.sessionGui.greeter.tuigreet.user" missingTuigreetUser)
  "tuigreet accepted a user absent from users.users";
assert failsAssertion "dotfiles.features.sessionGui.greeter" disabledSessionDiscovery;
assert failsAssertion "dotfiles.features.sessionGui.greeter" wrongNoctaliaSession;
assert failsAssertion "dotfiles.features.sessionGui.greeter" wrongTuigreetCommand;
assert failsAssertion "dotfiles.features.sessionGui.greeter" wrongNoctaliaCommand;
assert !unsupportedSession.success;
pkgs.runCommandLocal "session-gui-nixos-eval-test" { } ''touch "$out"''
