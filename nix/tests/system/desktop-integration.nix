{
  lib,
  pkgs,
  self,
}:
let
  homeCases = lib.cartesianProduct {
    host = [
      "x86_64-linux-a"
      "aarch64-linux-a"
    ];
    theme = [
      "light"
      "dark"
    ];
    session = [
      "gui"
      "tty"
    ];
  };
  deployments = {
    x86_64-linux-a = [ "native" ];
    aarch64-linux-a = [
      "parallels"
      "qemu"
    ];
  };
  systemCases = lib.concatMap (
    case: map (deployment: case // { inherit deployment; }) deployments.${case.host}
  ) homeCases;
  homeName = case: "${case.host}--account-a--theme-${case.theme}--session-${case.session}";
  systemName =
    case: "${case.host}--deployment-${case.deployment}--theme-${case.theme}--session-${case.session}";
  expect = name: condition: lib.assertMsg condition "desktopIntegration hosts: ${name}";
  chooser = "org.freedesktop.impl.portal.FileChooser";
  chooserConfig = "xdg-desktop-portal-termfilechooser/config";
  homePortal = "xdg-desktop-portal/niri-portals.conf";
  systemPortal = "xdg/${homePortal}";
  portalPolicy = {
    default = "gnome;gtk";
    "org.freedesktop.impl.portal.Access" = "gtk";
    ${chooser} = "termfilechooser";
    "org.freedesktop.impl.portal.Notification" = "gtk";
    "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
  };
  desktopMime = {
    "inode/directory" = [ "yazi.desktop" ];
    "text/uri-list" = [ "yazi.desktop" ];
    "text/plain" = [ "emacsclient.desktop" ];
    "x-scheme-handler/org-protocol" = [ "org-protocol.desktop" ];
    "text/html" = [ "glide.desktop" ];
    "application/xhtml+xml" = [ "glide.desktop" ];
    "x-scheme-handler/http" = [ "glide.desktop" ];
    "x-scheme-handler/https" = [ "glide.desktop" ];
  };

  # Select source positions before forcing booleans: unrelated embedded Home
  # assertions evaluate Catppuccin Bottom's IFD source. Standalone HM's public
  # config wrapper still checks all of its assertions and can require theme IFD
  # sources. This is not a full host/Home build. Keep package checks to names;
  # no home.packages or host-architecture builds are requested by this check.
  relevantAssertions =
    config:
    lib.filter (
      entry:
      let
        position = builtins.unsafeGetAttrPos "assertion" entry;
      in
      position != null
      && lib.any (source: lib.hasSuffix source position.file) [
        "/nix/modules/nixos/features/desktop-integration.nix"
        "/nix/modules/home/features/desktop-integration.nix"
        "/nix/modules/home/features/desktop-integration/portal.nix"
        "/nix/modules/home/features/desktop-integration/termfilechooser.nix"
        "/nix/modules/home/features/desktop-integration/org-protocol.nix"
      ]
    ) config.assertions;
  assertContracts =
    name: config:
    let
      assertions = relevantAssertions config;
    in
    expect "${name}: contract assertion source metadata remains available" (
      !config.dotfiles.features.desktopIntegration.enable || assertions != [ ]
    )
    && lib.all (entry: expect "${name}: ${entry.message}" entry.assertion) assertions;
  checkPortal =
    name: gui: config: expectedPackages:
    expect "${name}: Feature and Portal gates follow runtime policy" (
      config.dotfiles.features.desktopIntegration.enable == gui && config.xdg.portal.enable == gui
    )
    && expect "${name}: managed chooser selection and backend provision" (
      (config.xdg.portal.config.niri or { }) == (if gui then portalPolicy else { })
      &&
        lib.sort builtins.lessThan (map lib.getName config.xdg.portal.extraPortals)
        == lib.sort builtins.lessThan (if gui then expectedPackages else [ ])
    )
    && assertContracts name config;
  checkHome =
    name: case: config:
    let
      gui = case.session == "gui";
      files = config.xdg.configFile;
      defaults = config.xdg.mimeApps.defaultApplications;
    in
    checkPortal name gui config [ "xdg-desktop-portal-termfilechooser" ]
    && expect "${name}: Portal and chooser files follow GUI selection" (
      builtins.hasAttr homePortal files == gui && builtins.hasAttr chooserConfig files == gui
    )
    && expect "${name}: user Portal file has the selected policy" (
      !gui
      || (
        files.${homePortal}.text == lib.generators.toINI { } { preferred = portalPolicy; }
        &&
          "${config.home.homeDirectory}/${files.${homePortal}.target}"
          == "${config.xdg.configHome}/${homePortal}"
        && lib.hasInfix "[filechooser]" files.${chooserConfig}.text
        && lib.hasInfix "cmd=/nix/store/" files.${chooserConfig}.text
      )
    )
    && expect "${name}: Org Protocol entry follows Feature distribution" (
      builtins.hasAttr "org-protocol" config.xdg.desktopEntries == gui
      && (
        !gui
        || (
          config.xdg.desktopEntries.org-protocol.mimeType == [ "x-scheme-handler/org-protocol" ]
          && !config.xdg.desktopEntries.org-protocol.terminal
        )
      )
    )
    && expect "${name}: desktop MIME contributions follow GUI policy" (
      lib.all (mime: (defaults.${mime} or [ ]) == (if gui then desktopMime.${mime} else [ ])) (
        builtins.attrNames desktopMime
      )
    )
    && expect "${name}: independent media MIME defaults survive TTY" (
      config.xdg.mimeApps.enable
      && lib.all (mime: defaults.${mime} == [ "mpv.desktop" ]) [
        "audio/*"
        "image/*"
        "video/*"
      ]
    )
    && expect "${name}: Terminal and Keyring ownership remain independent" (
      config.dotfiles.features.terminal.enable
      && config.dotfiles.features.terminal.provider == "kitty"
      && !config.services.gnome-keyring.enable
    );
  checkSystem =
    case:
    let
      name = systemName case;
      config = self.nixosConfigurations.${name}.config;
      home = config.home-manager.users.a;
      gui = case.session == "gui";
      etc = config.environment.etc;
    in
    checkPortal name gui config [
      "xdg-desktop-portal-termfilechooser"
      "xdg-desktop-portal-gnome"
      "xdg-desktop-portal-gtk"
      "gnome-keyring"
    ]
    && expect "${name}: Keyring follows the independent Niri session" (
      config.programs.niri.enable == gui && config.services.gnome.gnome-keyring.enable == gui
    )
    && expect "${name}: system Portal file follows GUI policy" (
      builtins.hasAttr systemPortal etc == gui
    )
    && checkHome "${name} embedded Home" case home
    && expect "${name}: system and Home policies coexist at distinct locations" (
      !gui
      || (
        etc.${systemPortal}.text == home.xdg.configFile.${homePortal}.text
        && "/etc/${etc.${systemPortal}.target}" == "/etc/xdg/${homePortal}"
        &&
          "/etc/${etc.${systemPortal}.target}"
          != "${home.home.homeDirectory}/${home.xdg.configFile.${homePortal}.target}"
      )
    );
in
assert lib.all (
  case: checkHome (homeName case) case self.homeConfigurations.${homeName case}.config
) homeCases;
assert lib.all checkSystem systemCases;
pkgs.runCommandLocal "desktop-integration-host-contract-test" { } ''touch "$out"''
