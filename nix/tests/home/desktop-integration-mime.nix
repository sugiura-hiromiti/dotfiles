{
  lib,
  pkgs,
  home-manager,
}:
let
  fixture = import ./desktop-integration-fixture.nix { inherit lib pkgs home-manager; };
  evaluate =
    feature: extra:
    fixture
      (
        {
          enable = true;
          portal.enable = false;
          mimeApps.enable = true;
          # Let the production option default follow final programs.emacs.enable.
          orgProtocol.enable = lib.mkOverride 1600 false;
        }
        // feature
      )
      {
        imports = [ extra ];
        # MIME chooses a desktop ID; the browser module owns its provision.
        options.dotfiles.programs.glide.enable = lib.mkEnableOption "test Glide selection";
      };

  failures = config: map (entry: if entry.assertion then null else entry.message) config.assertions;
  valid =
    config: builtins.deepSeq (failures config) (lib.all (message: message == null) (failures config));
  defaults = config: config.xdg.mimeApps.defaultApplications;
  orgScheme = "x-scheme-handler/org-protocol";
  browserTypes = [
    "text/html"
    "application/xhtml+xml"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
  ];
  browserIs = desktop: config: lib.all (mime: (defaults config).${mime} == [ desktop ]) browserTypes;

  # Catch accidental browser selection without a selected browser, and retain
  # the existing Yazi policy without requiring the Yazi program to be enabled.
  noBrowser = evaluate { } { };
  qutebrowser = evaluate { } { programs.qutebrowser.enable = true; };
  glide = evaluate { } { dotfiles.programs.glide.enable = true; };
  bothBrowsers = evaluate { } {
    programs.qutebrowser.enable = true;
    dotfiles.programs.glide.enable = true;
  };

  # text/plain follows the desktop entry supplied by HM's Emacs service,
  # independently from the Emacs program that defaults Org Protocol on.
  serviceWithoutClient = evaluate { } { services.emacs.enable = true; };
  clientWithoutService = evaluate { } { services.emacs.client.enable = true; };
  serviceWithClient = evaluate { } {
    services.emacs = {
      enable = true;
      client.enable = true;
    };
  };
  emacsWithoutService = evaluate { } { programs.emacs.enable = true; };
  finalEmacsDisabled = evaluate { } {
    imports = [ { programs.emacs.enable = lib.mkDefault true; } ];
    programs.emacs.enable = false;
  };

  # The fake replaces only the external Emacs process. HM still generates the
  # desktop entry and MIME file that the runtime test consumes below.
  fakeEmacs = pkgs.writeShellScriptBin "emacsclient" ''
    printf '%s\0' "$@" > "$TEST_EMACSCLIENT_ARGS"
  '';
  customOrg = evaluate {
    orgProtocol = {
      enable = true;
      emacsPackage = fakeEmacs;
    };
  } { programs.emacs.enable = true; };
  missingEmacs = evaluate {
    orgProtocol = {
      enable = true;
      emacsPackage = fakeEmacs;
    };
  } { };
  orgDisabled = evaluate {
    orgProtocol = {
      enable = false;
      emacsPackage = throw "disabled Org Protocol evaluated its Emacs package";
    };
  } { programs.emacs.enable = true; };
  mimeDisabled = evaluate {
    mimeApps.enable = false;
    orgProtocol = {
      enable = true;
      emacsPackage = fakeEmacs;
    };
  } { programs.emacs.enable = true; };

  # An ordinary public API assignment replaces the whole automatic map,
  # including defaults whose providers remain independently enabled.
  hostDefaults =
    evaluate
      {
        mimeApps.defaultApplications."text/html" = [
          "host-first.desktop"
          "host-second.desktop"
        ];
      }
      {
        programs.emacs.enable = true;
        programs.qutebrowser.enable = true;
        dotfiles.programs.glide.enable = true;
      };
  hostScalar = evaluate {
    mimeApps.defaultApplications."inode/directory" = "host-files.desktop";
  } { };

  independent = {
    programs = {
      emacs.enable = true;
      qutebrowser.enable = true;
      yazi.enable = true;
    };
    dotfiles.programs.glide.enable = true;
    xdg = {
      mimeApps = {
        enable = true;
        defaultApplications."application/pdf" = "independent.desktop";
      };
      desktopEntries.independent = {
        name = "Independent";
        exec = "true";
      };
    };
  };
  featureDisabled = evaluate {
    enable = false;
    orgProtocol = {
      enable = true;
      emacsPackage = throw "disabled desktop integration evaluated its Emacs package";
    };
  } independent;
  selectionsDisabled = evaluate {
    mimeApps.enable = false;
    orgProtocol = {
      enable = false;
      emacsPackage = throw "disabled Org and MIME selections evaluated their Emacs package";
    };
  } independent;

  orgDesktopPackage =
    lib.findSingle (package: lib.getName package == "org-protocol.desktop")
      (throw "Org Protocol did not install its generated desktop entry")
      (throw "Org Protocol installed multiple desktop entries")
      customOrg.home.packages;
in
assert lib.assertMsg (lib.all valid [
  noBrowser
  qutebrowser
  glide
  bothBrowsers
  serviceWithoutClient
  clientWithoutService
  serviceWithClient
  emacsWithoutService
  finalEmacsDisabled
  customOrg
  orgDisabled
  mimeDisabled
  hostDefaults
  hostScalar
  featureDisabled
  selectionsDisabled
]) "valid MIME and Org Protocol configurations must satisfy every assertion";
assert
  defaults noBrowser == {
    "inode/directory" = [ "yazi.desktop" ];
    "text/uri-list" = [ "yazi.desktop" ];
  };
assert !noBrowser.programs.yazi.enable;
assert lib.assertMsg (browserIs "org.qutebrowser.qutebrowser.desktop" qutebrowser)
  "Qutebrowser selection must reach all browser MIME defaults";
assert lib.assertMsg (browserIs "glide.desktop" glide)
  "Glide selection must reach all browser MIME defaults";
assert lib.assertMsg (browserIs "glide.desktop" bothBrowsers)
  "Glide must retain the existing precedence when both browsers are selected";
assert !(defaults serviceWithoutClient ? "text/plain");
assert !(defaults clientWithoutService ? "text/plain");
assert (defaults serviceWithClient)."text/plain" == [ "emacsclient.desktop" ];
assert !(serviceWithClient.xdg.desktopEntries ? org-protocol);
assert !(defaults emacsWithoutService ? "text/plain");
assert (defaults emacsWithoutService).${orgScheme} == [ "org-protocol.desktop" ];
assert
  emacsWithoutService.xdg.desktopEntries.org-protocol.exec
  == "${emacsWithoutService.programs.emacs.finalPackage}/bin/emacsclient -n -r -- %u";
assert !(finalEmacsDisabled.xdg.desktopEntries ? org-protocol);
assert !(defaults finalEmacsDisabled ? ${orgScheme});
assert lib.assertMsg (builtins.deepSeq (failures missingEmacs) (
  lib.any (
    message:
    message != null
    && lib.hasInfix "desktopIntegration.orgProtocol" message
    && lib.hasInfix "programs.emacs.enable" message
  ) (failures missingEmacs)
)) "explicit Org Protocol without Emacs must report its dependency";
assert !(orgDisabled.xdg.desktopEntries ? org-protocol);
assert !(defaults orgDisabled ? ${orgScheme});
assert orgDisabled.programs.emacs.enable;
assert !mimeDisabled.xdg.mimeApps.enable;
assert defaults mimeDisabled == { };
assert mimeDisabled.xdg.desktopEntries.org-protocol.mimeType == [ orgScheme ];
assert
  defaults hostDefaults == {
    "text/html" = [
      "host-first.desktop"
      "host-second.desktop"
    ];
  };
assert hostDefaults.xdg.desktopEntries ? org-protocol;
assert defaults hostScalar == { "inode/directory" = [ "host-files.desktop" ]; };
assert lib.all
  (
    config:
    config.programs.emacs.enable
    && config.programs.qutebrowser.enable
    && config.programs.yazi.enable
    && config.dotfiles.programs.glide.enable
    && config.xdg.mimeApps.enable
    && defaults config == { "application/pdf" = [ "independent.desktop" ]; }
    && config.xdg.desktopEntries ? independent
    && !(config.xdg.desktopEntries ? org-protocol)
  )
  [
    featureDisabled
    selectionsDisabled
  ];
pkgs.runCommandLocal "desktop-integration-mime-home-test"
  {
    nativeBuildInputs = [ pkgs.python3 ];
    desktopFile = "${orgDesktopPackage}/share/applications/org-protocol.desktop";
    mimeFile = customOrg.xdg.configFile."mimeapps.list".source;
  }
  ''
    export TEST_EMACSCLIENT_ARGS="$TMPDIR/emacsclient-args"
    python3 - <<'PY'
    import configparser
    import os
    import pathlib
    import shlex
    import subprocess

    desktop = configparser.ConfigParser(interpolation=None)
    desktop.read(os.environ["desktopFile"])
    entry = desktop["Desktop Entry"]
    assert entry["Type"] == "Application"
    assert entry.getboolean("Terminal") is False
    assert entry["MimeType"].rstrip(";").split(";") == ["x-scheme-handler/org-protocol"]

    mime = configparser.ConfigParser(interpolation=None)
    mime.read(os.environ["mimeFile"])
    assert mime["Default Applications"]["x-scheme-handler/org-protocol"] == "org-protocol.desktop"

    command = shlex.split(entry["Exec"])
    assert command[0] == "${fakeEmacs}/bin/emacsclient", command
    url = "org-protocol://capture?template=c&title=two words&url=https%3A%2F%2Fexample.com"
    command = [url if argument == "%u" else argument for argument in command]
    subprocess.run(command, check=True)
    arguments = pathlib.Path(os.environ["TEST_EMACSCLIENT_ARGS"]).read_bytes().split(b"\0")
    assert arguments == [b"-n", b"-r", b"--", url.encode(), b""], arguments
    PY
    touch "$out"
  ''
