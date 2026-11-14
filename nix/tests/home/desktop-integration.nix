{
  lib,
  pkgs,
  home-manager,
}:
let
  # Keep negative cases observable without HM's assertion-throwing wrapper.
  evaluate = import ./desktop-integration-fixture.nix { inherit lib pkgs home-manager; };

  chooser = "org.freedesktop.impl.portal.FileChooser";
  chooserConfig = "xdg-desktop-portal-termfilechooser/config";
  contains = package: packages: lib.elem (toString package) (map toString packages);
  failures = config: map (entry: if entry.assertion then null else entry.message) config.assertions;
  valid =
    config: builtins.deepSeq (failures config) (lib.all (message: message == null) (failures config));
  failsWith =
    fragment: config:
    builtins.deepSeq (failures config) (
      lib.any (
        message:
        message != null
        && lib.hasInfix "dotfiles.features.desktopIntegration" message
        && lib.hasInfix fragment message
      ) (failures config)
    );

  # Disabling the portal used to leave a terminal chooser wrapper deployed.
  portalOff = evaluate {
    enable = true;
    portal.enable = false;
  } { };
  enabled = evaluate { enable = true; } { };
  disabled = evaluate { } { };
  inactiveDependencies = {
    dotfiles.features = {
      terminal.enable = false;
      desktopIntegration.termfilechooser = {
        package = throw "inactive termfilechooser package was evaluated";
        fileManager.package = throw "inactive file manager was evaluated";
      };
    };
  };
  gtk = evaluate {
    enable = true;
    portal.fileChooser.backend = "gtk";
  } inactiveDependencies;
  unmanaged =
    evaluate
      {
        enable = true;
        portal.fileChooser.backend = null;
      }
      {
        imports = [ inactiveDependencies ];
        # null leaves backend provision to the session/other consumers.
        xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
        xdg.portal.config.niri.${chooser} = "external";
      };
  inactive = evaluate {
    enable = true;
    portal.enable = false;
  } inactiveDependencies;
  disabledWithUnusedDependencies = evaluate { } inactiveDependencies;
  sharedPortal = evaluate { } {
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.other.${chooser} = "gtk";
    };
  };
  customPackage = pkgs.xdg-desktop-portal-termfilechooser.overrideAttrs {
    pname = "desktop-test-termfilechooser";
  };
  customized = evaluate {
    enable = true;
    portal.configName = "other";
    termfilechooser.package = customPackage;
  } { };
  blockedEngine = evaluate { enable = true; } { xdg.portal.enable = false; };
  missingTerminal = evaluate { enable = true; } { dotfiles.features.terminal.enable = false; };
  missingBackend = evaluate { enable = true; } { xdg.portal.extraPortals = lib.mkForce [ ]; };
  wrongBackend = evaluate { enable = true; } {
    xdg.portal.config.niri.${chooser} = lib.mkForce "gtk";
  };
  unsupportedBackend =
    builtins.tryEval
      (evaluate {
        enable = true;
        portal.fileChooser.backend = "unknown";
      } { }).dotfiles.features.desktopIntegration.portal.fileChooser.backend;
  removedBackend = evaluate {
    portal.fileChooserBackend = "gtk";
  } { };
  removedToggle = evaluate {
    termfilechooser.enable = false;
  } { };
  customPolicy = evaluate {
    enable = true;
    portal = {
      configName = "common";
      fileChooser.backend = null;
      defaultBackends = [
        "external"
        "gtk"
      ];
      accessBackend = "external-access";
      notificationBackend = "external-notification";
      secretBackend = "external-secret";
    };
  } { xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ]; };
  contradictoryPolicies =
    map
      (
        key:
        evaluate {
          enable = true;
        } { xdg.portal.config.niri.${key} = lib.mkForce "wrong"; }
      )
      [
        "default"
        "org.freedesktop.impl.portal.Access"
        "org.freedesktop.impl.portal.Notification"
        "org.freedesktop.impl.portal.Secret"
      ];
  sharedKeyring =
    map
      (
        feature:
        evaluate feature {
          services.gnome-keyring.enable = true;
        }
      )
      [
        { }
        {
          enable = true;
          portal.enable = false;
        }
      ];
in
assert lib.assertMsg (
  !(portalOff.xdg.configFile ? ${chooserConfig})
) "portal.enable=false still deploys the termfilechooser wrapper";
assert lib.all valid [
  enabled
  disabled
  portalOff
  gtk
  unmanaged
  inactive
  disabledWithUnusedDependencies
  sharedPortal
  customized
  customPolicy
];
assert enabled.xdg.portal.enable;
assert enabled.xdg.portal.config.niri.${chooser} == "termfilechooser";
assert enabled.xdg.portal.extraPortals == [ pkgs.xdg-desktop-portal-termfilechooser ];
assert contains pkgs.xdg-desktop-portal-termfilechooser enabled.home.packages;
assert enabled.xdg.configFile ? ${chooserConfig};
assert !disabled.xdg.portal.enable;
assert disabled.xdg.portal.extraPortals == [ ];
assert disabled.xdg.portal.config == { };
assert !(disabled.xdg.configFile ? ${chooserConfig});
assert !portalOff.xdg.portal.enable;
assert portalOff.xdg.portal.extraPortals == [ ];
assert portalOff.xdg.portal.config == { };
assert gtk.xdg.portal.config.niri.${chooser} == "gtk";
assert gtk.xdg.portal.extraPortals == [ pkgs.xdg-desktop-portal-gtk ];
assert contains pkgs.xdg-desktop-portal-gtk gtk.home.packages;
assert !(contains pkgs.xdg-desktop-portal-termfilechooser gtk.home.packages);
assert !(gtk.xdg.configFile ? ${chooserConfig});
assert unmanaged.xdg.portal.extraPortals == [ pkgs.xdg-desktop-portal-gnome ];
assert unmanaged.xdg.portal.config.niri.${chooser} == "external";
assert !(unmanaged.xdg.configFile ? ${chooserConfig});
assert !(inactive.xdg.configFile ? ${chooserConfig});
assert !(disabledWithUnusedDependencies.xdg.configFile ? ${chooserConfig});
assert sharedPortal.xdg.portal.enable;
assert sharedPortal.xdg.portal.extraPortals == [ pkgs.xdg-desktop-portal-gtk ];
assert sharedPortal.xdg.portal.config.other.${chooser} == "gtk";
assert customized.xdg.portal.config.other.${chooser} == "termfilechooser";
assert !(customized.xdg.portal.config ? niri);
assert customized.xdg.portal.extraPortals == [ customPackage ];
assert
  customized.xdg.configFile.${chooserConfig}.text != enabled.xdg.configFile.${chooserConfig}.text;
assert failsWith "xdg.portal.enable" blockedEngine;
assert lib.assertMsg (failsWith "terminal.enable" missingTerminal)
  "termfilechooser must diagnose a disabled terminal before evaluating terminal.selected";
assert !(missingTerminal.xdg.configFile ? ${chooserConfig});
assert failsWith "xdg.portal.extraPortals" missingBackend;
assert failsWith "portal.fileChooser.backend" wrongBackend;
assert !unsupportedBackend.success;
assert failsWith "portal.fileChooserBackend" removedBackend;
assert failsWith "termfilechooser.enable" removedToggle;
assert !enabled.services.gnome-keyring.enable;
assert lib.all (config: config.services.gnome-keyring.enable && valid config) sharedKeyring;
assert customPolicy.xdg.portal.config.common.default == "external;gtk";
assert lib.hasInfix "org.freedesktop.impl.portal.Secret=external-secret"
  customPolicy.xdg.configFile."xdg-desktop-portal/portals.conf".text;
assert lib.all (failsWith "portal.") contradictoryPolicies;
pkgs.runCommandLocal "desktop-integration-home-eval-test" { } ''touch "$out"''
