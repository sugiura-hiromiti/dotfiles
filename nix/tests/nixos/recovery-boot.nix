{ lib, pkgs }:
let
  primary = "recovery-test";
  evaluate =
    boot:
    (lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      specialArgs.accounts.primary = primary;
      modules = [
        ../../modules/nixos/base/boot.nix
        ../../modules/nixos/features/session-gui.nix
        {
          boot.isContainer = true;
          fileSystems."/".fsType = "tmpfs";
          system.stateVersion = "26.05";
          users.users.${primary}.isNormalUser = true;
          dotfiles.nixos.boot = boot;
          dotfiles.features.sessionGui.enable = true;
          # A separate consumer may enable this shared Program.
          programs.xwayland.enable = true;
        }
      ];
    }).config;

  withoutRecovery = evaluate { };
  disabledBoot = evaluate {
    enable = false;
    noGuiSpecialisation.enable = true;
  };
  graphical = evaluate { noGuiSpecialisation.enable = true; };
  recovery = graphical.specialisation.no-gui.configuration;
  assertions = lib.concatMap (config: map (entry: entry.assertion) config.assertions) [
    withoutRecovery
    disabledBoot
    graphical
    recovery
  ];
  expect = name: condition: lib.assertMsg condition "recovery boot: ${name}";
in
# Force every NixOS assertion, including the specialised child's assertions.
assert builtins.deepSeq assertions (lib.all (assertion: assertion) assertions);
assert expect "disabled recovery policy does not create a boot entry" (
  withoutRecovery.specialisation == { } && disabledBoot.specialisation == { }
);
assert expect "normal GUI boot retains its graphical target" (
  graphical.systemd.defaultUnit == "graphical.target"
  && !lib.elem "getty@tty1.service" graphical.systemd.targets.getty.wants
);
assert expect "no-gui boots to the console target" (
  recovery.systemd.defaultUnit == "multi-user.target" && lib.elem "no-gui" recovery.system.nixos.tags
);
assert expect "no-gui explicitly requests the canonical tty1 getty" (
  lib.elem "getty@tty1.service" recovery.systemd.targets.getty.wants
);
assert expect "tty1 can use the supplied unmasked getty template" (
  lib.elem "getty@.service" recovery.systemd.additionalUpstreamSystemUnits
  && recovery.systemd.units."getty@.service".enable
  && (recovery.systemd.units."getty@tty1.service".enable or true)
  && recovery.systemd.services."getty@".serviceConfig.ExecStart != [ ]
);
assert expect "greetd keeps its autovt mask and graphical activation" (
  !recovery.systemd.services."autovt@tty1".enable
  && recovery.systemd.services.greetd.wantedBy == [ "graphical.target" ]
);
assert expect "the recovery entry retains the configured GUI and shared Xwayland" (
  recovery.programs.niri.enable
  && recovery.services.greetd.enable
  && recovery.services.displayManager.noctalia-greeter.enable
  && recovery.services.greetd.settings == graphical.services.greetd.settings
  && recovery.programs.xwayland.enable
);
assert expect "the recovery entry preserves authentication policy" (
  recovery.services.getty.autologinUser == null
  && recovery.services.displayManager.noctalia-greeter.passwordlessSyncUsers == [ primary ]
  && recovery.users.users.${primary} == graphical.users.users.${primary}
);
pkgs.runCommandLocal "recovery-boot-nixos-eval-test" { } ''touch "$out"''
