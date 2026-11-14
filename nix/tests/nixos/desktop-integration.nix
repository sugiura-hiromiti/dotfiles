{ lib, pkgs }:
let
  fileChooser = "org.freedesktop.impl.portal.FileChooser";
  evaluate =
    feature: extra:
    (lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../../modules/nixos/features/desktop-integration.nix
        {
          boot.isContainer = true;
          system.stateVersion = "26.05";
          dotfiles.features.desktopIntegration = feature;
        }
        extra
      ];
    }).config;

  contains = package: packages: lib.elem (toString package) (map toString packages);
  chooser = name: config: lib.attrByPath [ name fileChooser ] null config.xdg.portal.config;
  assertionFailures =
    config: map (entry: if entry.assertion then null else entry.message) config.assertions;
  failsAssertion =
    fragments: config:
    let
      failures = assertionFailures config;
    in
    # Force every assertion, including those following the expected failure.
    builtins.deepSeq failures (
      lib.any (
        message: message != null && lib.all (fragment: lib.hasInfix fragment message) fragments
      ) failures
    );

  enabled = evaluate { enable = true; } { };
  gtk = evaluate {
    enable = true;
    portal.fileChooser.backend = "gtk";
    termfilechooser.package = throw "GTK must not evaluate the termfilechooser package";
  } { };
  unmanaged =
    evaluate
      {
        enable = true;
        portal.fileChooser.backend = null;
        termfilechooser.package = throw "null must not evaluate the termfilechooser package";
      }
      {
        # With no managed chooser, the session/system supplies a backend. The
        # former unconditional Keyring request used to hide this prerequisite.
        xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
      };
  disabled = evaluate {
    termfilechooser.package = throw "disabled feature must not evaluate the chooser package";
  } { };
  portalDisabled = evaluate {
    enable = true;
    portal.enable = false;
    termfilechooser.package = throw "disabled portal must not evaluate the chooser package";
  } { };

  externalPortal = {
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.niri.${fileChooser} = "external";
    };
  };
  unmanagedExternal = evaluate {
    enable = true;
    portal.fileChooser.backend = null;
  } externalPortal;
  disabledExternal = evaluate { } externalPortal;
  portalDisabledExternal = evaluate {
    enable = true;
    portal.enable = false;
  } externalPortal;

  customPackage = pkgs.xdg-desktop-portal-termfilechooser.overrideAttrs {
    pname = "desktop-test-termfilechooser";
  };
  customized = evaluate {
    enable = true;
    portal.configName = "custom-desktop";
    termfilechooser.package = customPackage;
  } { };
  withNiri = evaluate { enable = true; } {
    programs.niri = {
      enable = true;
      useNautilus = false;
    };
  };
  niriOnly = evaluate { } { programs.niri.enable = true; };
  niriPortalDisabled = evaluate {
    enable = true;
    portal.enable = false;
  } { programs.niri.enable = true; };
  externalKeyring =
    map
      (
        feature:
        evaluate feature {
          services.gnome.gnome-keyring.enable = true;
        }
      )
      [
        { }
        { enable = true; }
        {
          enable = true;
          portal.enable = false;
        }
      ];

  finalPortalDisabled = evaluate { enable = true; } {
    xdg.portal.enable = lib.mkForce false;
  };
  missingTermPackage = evaluate { enable = true; } {
    # Keep a backend present so the generic upstream assertion cannot satisfy
    # the test for our selected, managed implementation's presence.
    xdg.portal.extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-gtk ];
  };
  missingGtkPackage =
    evaluate
      {
        enable = true;
        portal.fileChooser.backend = "gtk";
      }
      {
        xdg.portal.extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-termfilechooser ];
      };
  wrongFinalChooser = evaluate { enable = true; } {
    # Stronger than mkForce: normal-priority Niri config must compose, while
    # an explicit override of the managed choice must produce a diagnostic.
    xdg.portal.config.niri.${fileChooser} = lib.mkOverride 10 "gtk";
  };
  wrongCustomChooser =
    evaluate
      {
        enable = true;
        portal.configName = "custom-desktop";
        portal.fileChooser.backend = "gtk";
      }
      {
        xdg.portal.config.custom-desktop.${fileChooser} = lib.mkOverride 10 "termfilechooser";
      };
  oldBackend = evaluate {
    enable = true;
    portal.fileChooserBackend = "gtk";
  } { };
  oldEnable = evaluate {
    enable = true;
    termfilechooser.enable = false;
  } { };
  unsupportedBackend = builtins.tryEval (
    let
      config = evaluate {
        enable = true;
        portal.fileChooser.backend = "unsupported-backend";
      } { };
    in
    builtins.deepSeq [
      config.dotfiles.features.desktopIntegration.portal.fileChooser.backend
      (assertionFailures config)
    ] true
  );

  positiveFailures =
    lib.concatMap assertionFailures [
      enabled
      gtk
      unmanaged
      disabled
      portalDisabled
      unmanagedExternal
      disabledExternal
      portalDisabledExternal
      customized
      withNiri
      niriOnly
      niriPortalDisabled
    ]
    ++ lib.concatMap assertionFailures externalKeyring;
in
assert lib.assertMsg
  (builtins.deepSeq positiveFailures (lib.all (message: message == null) positiveFailures))
  (
    "valid standalone NixOS desktopIntegration configurations must satisfy every assertion:\n"
    + lib.concatStringsSep "\n" (lib.filter (message: message != null) positiveFailures)
  );
assert enabled.dotfiles.features.desktopIntegration.portal.fileChooser.backend == "termfilechooser";
assert enabled.xdg.portal.enable;
assert chooser "niri" enabled == "termfilechooser";
assert contains pkgs.xdg-desktop-portal-termfilechooser enabled.xdg.portal.extraPortals;
assert contains pkgs.xdg-desktop-portal-termfilechooser enabled.environment.systemPackages;
assert gtk.xdg.portal.enable;
assert chooser "niri" gtk == "gtk";
assert contains pkgs.xdg-desktop-portal-gtk gtk.xdg.portal.extraPortals;
assert contains pkgs.xdg-desktop-portal-gtk gtk.environment.systemPackages;
assert !contains pkgs.xdg-desktop-portal-termfilechooser gtk.xdg.portal.extraPortals;
assert !contains pkgs.xdg-desktop-portal-termfilechooser gtk.environment.systemPackages;
assert chooser "niri" unmanaged == null;
assert !contains pkgs.xdg-desktop-portal-termfilechooser unmanaged.xdg.portal.extraPortals;
assert !contains pkgs.xdg-desktop-portal-gtk unmanaged.xdg.portal.extraPortals;
assert chooser "niri" disabled == null;
assert !contains pkgs.xdg-desktop-portal-termfilechooser disabled.xdg.portal.extraPortals;
assert !contains pkgs.xdg-desktop-portal-gtk disabled.xdg.portal.extraPortals;
assert chooser "niri" portalDisabled == null;
assert !contains pkgs.xdg-desktop-portal-termfilechooser portalDisabled.xdg.portal.extraPortals;
assert !contains pkgs.xdg-desktop-portal-gtk portalDisabled.xdg.portal.extraPortals;
assert lib.all (config: config.xdg.portal.enable && chooser "niri" config == "external") [
  unmanagedExternal
  disabledExternal
  portalDisabledExternal
];
assert lib.all (config: contains pkgs.xdg-desktop-portal-gtk config.xdg.portal.extraPortals) [
  unmanagedExternal
  disabledExternal
  portalDisabledExternal
];
assert chooser "custom-desktop" customized == "termfilechooser";
assert chooser "niri" customized == null;
assert contains customPackage customized.xdg.portal.extraPortals;
assert contains customPackage customized.environment.systemPackages;
assert !contains pkgs.xdg-desktop-portal-termfilechooser customized.xdg.portal.extraPortals;
assert lib.hasInfix "org.freedesktop.impl.portal.FileChooser=termfilechooser"
  customized.environment.etc."xdg/xdg-desktop-portal/custom-desktop-portals.conf".text;
assert chooser "niri" withNiri == "termfilechooser";
assert lib.assertMsg (
  !enabled.services.gnome.gnome-keyring.enable
) "desktopIntegration must leave Keyring ownership to the session/system";
assert !portalDisabled.services.gnome.gnome-keyring.enable;
assert !disabled.services.gnome.gnome-keyring.enable;
assert lib.all (config: config.services.gnome.gnome-keyring.enable) (
  externalKeyring
  ++ [
    withNiri
    niriOnly
    niriPortalDisabled
  ]
);
assert niriPortalDisabled.xdg.portal.enable;
assert chooser "niri" niriOnly == null;
assert lib.assertMsg (failsAssertion [
  "xdg.portal.enable"
] finalPortalDisabled) "a selected FileChooser must reject final xdg.portal.enable=false";
assert lib.assertMsg (failsAssertion [
  "xdg.portal.extraPortals"
] missingTermPackage) "termfilechooser selection must reject its missing final portal package";
assert lib.assertMsg (failsAssertion [
  "xdg.portal.extraPortals"
] missingGtkPackage) "GTK selection must reject its missing final portal package";
assert lib.assertMsg (failsAssertion [
  "portal.fileChooser.backend"
] wrongFinalChooser) "termfilechooser selection must reject a contradictory final FileChooser";
assert lib.assertMsg (failsAssertion [
  "portal.fileChooser.backend"
] wrongCustomChooser) "GTK selection must validate the final FileChooser at the custom configName";
assert lib.assertMsg (failsAssertion [
  "portal.fileChooserBackend"
  "portal.fileChooser.backend"
] oldBackend) "the removed fileChooserBackend API must explain its replacement";
assert lib.assertMsg (failsAssertion [
  "termfilechooser.enable"
  "portal.fileChooser.backend"
] oldEnable) "the removed termfilechooser.enable API must explain the single backend choice";
assert lib.assertMsg (
  !unsupportedBackend.success
) "unsupported FileChooser backends must be rejected";
pkgs.runCommandLocal "desktop-integration-nixos-eval-test" { } ''touch "$out"''
