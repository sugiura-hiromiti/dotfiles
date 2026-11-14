let
  # Read-only host slices, not a contract test. Follow the current API; the
  # accompanying Markdown preserves the observations made before Task 2.
  flake = builtins.getFlake (toString ../../..);
  lib = flake.inputs.nixpkgs.lib;
  hostNames = [
    "x86_64-linux-a"
    "aarch64-linux-a"
  ];
  sessions = [
    "gui"
    "tty"
  ];
  homeNames = lib.concatMap (
    host: map (session: "${host}--account-a--theme-light--session-${session}") sessions
  ) hostNames;
  systemNames = lib.concatMap (
    host:
    lib.concatMap
      (
        deployment:
        map (session: "${host}--deployment-${deployment}--theme-light--session-${session}") sessions
      )
      (
        if host == "x86_64-linux-a" then
          [ "native" ]
        else
          [
            "parallels"
            "qemu"
          ]
      )
  ) hostNames;
  packageNames = map lib.getName;
  portal = config: {
    fileChooserBackend = config.dotfiles.features.desktopIntegration.portal.fileChooser.backend;
    enable = config.xdg.portal.enable;
    extraPortals = packageNames config.xdg.portal.extraPortals;
    config = config.xdg.portal.config;
  };
  home = config: {
    enable = config.dotfiles.features.desktopIntegration.enable;
    portal = portal config;
    termfilechooser = {
      config = config.xdg.configFile."xdg-desktop-portal-termfilechooser/config".text or null;
    };
    terminal = {
      enable = config.dotfiles.features.terminal.enable;
      provider = config.dotfiles.features.terminal.provider;
    };
    mimeApps = {
      enable = config.xdg.mimeApps.enable;
      defaults = config.xdg.mimeApps.defaultApplications;
    };
    orgProtocol = {
      enable = config.dotfiles.features.desktopIntegration.orgProtocol.enable;
      entry =
        if config.xdg.desktopEntries ? org-protocol then
          {
            inherit (config.xdg.desktopEntries.org-protocol)
              name
              exec
              mimeType
              terminal
              ;
          }
        else
          null;
    };
    keyring = config.services.gnome-keyring.enable;
    programs = {
      inherit (config.programs.yazi) enable;
      emacs = config.programs.emacs.enable;
      emacsService = config.services.emacs.enable;
      emacsClient = config.services.emacs.client.enable;
      qutebrowser = config.programs.qutebrowser.enable;
      glide = config.dotfiles.programs.glide.enable;
    };
    portalFiles = lib.mapAttrs (_: file: file.text) (
      lib.filterAttrs (name: _: lib.hasPrefix "xdg-desktop-portal/" name) config.xdg.configFile
    );
  };
  system = config: {
    enable = config.dotfiles.features.desktopIntegration.enable;
    portal = portal config;
    keyring = config.services.gnome.gnome-keyring.enable;
    niri = config.programs.niri.enable;
    portalFiles = lib.mapAttrs (_: file: file.text) (
      lib.filterAttrs (name: _: lib.hasPrefix "xdg/xdg-desktop-portal/" name) config.environment.etc
    );
    home = home config.home-manager.users.a;
  };
in
{
  standalone = lib.genAttrs homeNames (name: home flake.homeConfigurations.${name}.config);
  nixos = lib.genAttrs systemNames (name: system flake.nixosConfigurations.${name}.config);
}
