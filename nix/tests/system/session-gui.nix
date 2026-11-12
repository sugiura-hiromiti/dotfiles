{
  lib,
  pkgs,
  self,
}:
let
  hosts = [
    "x86_64-linux-a"
    "aarch64-linux-a"
  ];
  themes = [
    "dark"
    "light"
  ];
  sessions = [
    "gui"
    "tty"
  ];
  deployments = {
    x86_64-linux-a = [ "native" ];
    aarch64-linux-a = [
      "parallels"
      "qemu"
    ];
  };
  homeCases = lib.cartesianProduct {
    host = hosts;
    theme = themes;
    session = sessions;
  };
  systemCases = lib.concatMap (
    case: map (deployment: case // { inherit deployment; }) deployments.${case.host}
  ) homeCases;
  homeName = case: "${case.host}--account-a--theme-${case.theme}--session-${case.session}";
  systemName =
    case: "${case.host}--deployment-${case.deployment}--theme-${case.theme}--session-${case.session}";
  homeConfig = case: self.homeConfigurations.${homeName case}.config;
  systemConfig = case: self.nixosConfigurations.${systemName case}.config;
  expect = name: condition: lib.assertMsg condition "session-gui migration: ${name}";
  packageNames = packages: map lib.getName packages;
  hasPackage = name: packages: lib.any (package: lib.getName package == name) packages;
  hasFile = name: config: builtins.hasAttr name config.xdg.configFile;
  hasUserService = name: config: builtins.hasAttr name config.systemd.user.services;

  # Select by source before forcing booleans. Some upstream failure messages are
  # only defined when their assertion fails, and unrelated Home assertions also
  # evaluate Catppuccin Bottom's import-from-derivation source. Attribute source
  # positions survive embedded Home Manager evaluation as well as standalone HM.
  relevantAssertions =
    config:
    lib.filter (
      assertion:
      let
        position = builtins.unsafeGetAttrPos "assertion" assertion;
      in
      position != null
      && lib.any (source: lib.hasSuffix source position.file) [
        "/nix/modules/nixos/features/session-gui.nix"
        "/nix/modules/nixos/features/auto-rotation.nix"
        "/nix/modules/home/features/session-gui.nix"
        "/nix/modules/home/features/noctalia-shell.nix"
        "/nix/modules/home/programs/niri/default.nix"
      ]
    ) config.assertions;
  assertContracts =
    name: config:
    let
      assertions = relevantAssertions config;
    in
    expect "${name}: GUI contract assertion metadata remains available" (
      !config.dotfiles.features.sessionGui.enable || assertions != [ ]
    )
    && lib.all (assertion: expect "${name}: ${assertion.message}" assertion.assertion) assertions;

  checkHome =
    name: case: config:
    let
      gui = case.session == "gui";
      x12 = case.host == "x86_64-linux-a";
      programs = config.dotfiles.programs;
      services = config.systemd.user.services;
      migratedPackages = lib.filter (
        name:
        lib.elem name [
          "xwayland-satellite"
          "wvkbd"
          "osk-toggle"
          "noctalia"
          "fcitx5"
          "fcitx5-with-addons"
          "fcitx5-hazkey"
        ]
      ) (packageNames config.home.packages);
    in
    expect "${name}: session policy" (config.dotfiles.features.sessionGui.enable == gui)
    && expect "${name}: Niri setting distribution" (
      programs.niri.enable == gui && hasFile "niri" config == gui
    )
    && expect "${name}: GUI policy retains Niri's Noctalia integration" (
      programs.niri.noctalia.enable == gui
    )
    && expect "${name}: Noctalia shell and settings" (
      config.programs.noctalia.enable == gui && hasFile "noctalia/config.toml" config == gui
    )
    && expect "${name}: avatar sync follows the GUI shell" (
      hasUserService "noctalia-avatar-sync" config == gui
      && builtins.hasAttr "noctalia-avatar-sync" config.systemd.user.paths == gui
    )
    && expect "${name}: custom SKK rules" (
      programs.libskk.enable == gui && hasFile "libskk" config == gui
    )
    && expect "${name}: Xwayland Satellite follows GUI policy" (
      hasPackage "xwayland-satellite" config.home.packages == gui
    )
    && expect "${name}: Ironbar is an independent opt-in" (
      !programs.ironbar.enable && !hasFile "ironbar" config
    )
    && expect "${name}: OmniWM is an independent opt-in" (
      !programs.omniwm.enable && !hasFile "omniwm/settings.toml" config
    )
    && expect "${name}: OSK settings, package, toggle and service" (
      config.dotfiles.features.osk.enable == (gui && x12)
      && programs.wvkbd.enable == (gui && x12)
      && hasUserService "wvkbd" config == (gui && x12)
      && hasPackage "wvkbd" config.home.packages == (gui && x12)
      && hasPackage "osk-toggle" config.home.packages == (gui && x12)
    )
    && expect "${name}: TTY has no migrated GUI packages or user services" (
      gui
      || (
        migratedPackages == [ ]
        && !(services ? niri)
        && !(services ? fcitx5-daemon)
        && !(services ? hazkey-server)
      )
    )
    && expect "${name}: recovery CLI remains available" (
      lib.all (program: programs.${program}.enable) [
        "direnv"
        "git"
        "jujutsu"
        "nh"
        "nushell"
        "nvim"
        "ssh"
      ]
      && config.programs.git.enable
      && config.programs.jujutsu.enable
      && config.programs.nh.enable
      && config.programs.nushell.enable
      && hasPackage "neovim" config.home.packages
      && hasFile "nvim/init.lua" config
      && config.programs.ssh.enable
    )
    && assertContracts name config;

  checkSystem =
    case:
    let
      name = systemName case;
      config = systemConfig case;
      gui = case.session == "gui";
      x12 = case.host == "x86_64-linux-a";
      ime = config.i18n.inputMethod;
      settings = ime.fcitx5.settings;
      addonNames = packageNames ime.fcitx5.addons;
      etc = config.environment.etc;
      user = config.users.users.a;
      ssh = config.services.openssh.settings;
      migratedAddons = [
        "fcitx5-skk"
        "fcitx5-gtk"
        "fcitx5-hazkey"
        "fcitx5-virtualkeyboard-adapter"
      ];
    in
    expect "${name}: graphical session and Greeter" (
      config.dotfiles.features.sessionGui.enable == gui
      && config.programs.niri.enable == gui
      && hasUserService "niri" config == gui
      && config.services.displayManager.noctalia-greeter.enable == gui
      && config.services.greetd.enable == gui
    )
    && expect "${name}: boot profile and default target" (
      config.dotfiles.nixos.boot.noGuiSpecialisation.enable == gui
      && builtins.hasAttr "no-gui" config.specialisation == gui
      && config.systemd.defaultUnit == (if gui then "graphical.target" else "multi-user.target")
    )
    && expect "${name}: recovery console login" (
      gui
      || (
        config.services.getty.enable && lib.elem "autovt@tty1.service" config.systemd.targets.getty.wants
      )
    )
    && expect "${name}: no upstream Xwayland request" (!config.programs.xwayland.enable)
    && expect "${name}: input method policy" (
      config.dotfiles.nixos.inputMethod.enable == gui && ime.enable == gui
    )
    && expect "${name}: X12-only Hazkey and rotation" (
      (config.dotfiles.programs.hazkey.enable or false) == (gui && x12)
      && (config.services.hazkey.enable or false) == (gui && x12)
      && hasUserService "hazkey-server" config == (gui && x12)
      && config.dotfiles.features.autoRotation.enable == (gui && x12)
      && config.services.iio-niri.enable == (gui && x12)
      && hasUserService "iio-niri" config == (gui && x12)
    )
    && expect "${name}: X12-only OSK addon" (
      config.dotfiles.features.osk.enable == (gui && x12)
      && lib.elem "fcitx5-virtualkeyboard-adapter" addonNames == (gui && x12)
      && builtins.hasAttr "virtualkeyboardadapter" settings.addons == (gui && x12)
    )
    && expect "${name}: GUI SKK and X12 Hazkey coexist" (
      !gui
      || (
        ime.type == "fcitx5"
        && ime.fcitx5.waylandFrontend
        && lib.elem "fcitx5-skk" addonNames
        && lib.elem "fcitx5-gtk" addonNames
        && lib.elem "fcitx5-hazkey" addonNames == x12
        && settings.addons.skk.globalSection.Rule == "custom"
        && settings.inputMethod."Groups/0".DefaultIM == (if x12 then "hazkey" else "skk")
        && settings.inputMethod."Groups/0/Items/1".Name == (if x12 then "hazkey" else "skk")
        && (!x12 || settings.inputMethod."Groups/0/Items/2".Name == "skk")
        && etc ? "xdg/fcitx5/profile"
        && etc ? "xdg/fcitx5/conf/skk.conf"
      )
    )
    && expect "${name}: TTY has no active Fcitx artifacts or migrated addons" (
      gui
      || (
        lib.intersectLists migratedAddons addonNames == [ ]
        && settings.inputMethod == { }
        && settings.globalOptions == { }
        && !(settings.addons ? skk)
        && !(etc ? "xdg/fcitx5/profile")
        && !(etc ? "xdg/fcitx5/config")
        && !(etc ? "xdg/fcitx5/conf/skk.conf")
        && !(config.environment.variables ? XMODIFIERS)
        && ime.package == null
      )
    )
    && expect "${name}: networking and remote recovery" (
      config.networking.networkmanager.enable
      && config.services.openssh.enable
      && config.services.tailscale.enable
      && lib.elem 22 config.networking.firewall.allowedTCPPorts
      && !ssh.PasswordAuthentication
      && !ssh.KbdInteractiveAuthentication
      && ssh.PermitRootLogin == "no"
    )
    && expect "${name}: user, authorization, console and rebuild paths preserved" (
      user.isNormalUser
      && user.uid == 1000
      && lib.all (group: lib.elem group user.extraGroups) [
        "networkmanager"
        "wheel"
        "inputs"
      ]
      &&
        user.openssh.authorizedKeys.keys == (import ../../profiles/hosts/${case.host}/meta.nix)
        .accounts.users.a.authorizedKeys
      && lib.getName user.shell == "nushell"
      && config.security.sudo.wheelNeedsPassword
      && config.console.keyMap == "us"
      && config.i18n.defaultLocale == "en_US.UTF-8"
      && lib.all (feature: lib.elem feature config.nix.settings.experimental-features) [
        "nix-command"
        "flakes"
      ]
      && config.system.autoUpgrade.enable
      &&
        config.services.displayManager.noctalia-greeter.passwordlessSyncUsers
        == (if gui then [ "a" ] else [ ])
    )
    && assertContracts name config
    && checkHome "${name} embedded Home" case config.home-manager.users.a;

  # A no-gui boot keeps the GUI generation and its shared services installed.
  # Their start targets must stay graphical so multi-user does not launch them.
  checkNoGui =
    host:
    let
      case = {
        inherit host;
        theme = "dark";
        session = "gui";
        deployment = builtins.head deployments.${host};
      };
      name = systemName case;
      parent = systemConfig case;
      child = parent.specialisation.no-gui.configuration;
      wants = child.systemd.services.greetd.wantedBy;
    in
    expect "${name}: no-gui boot suppresses graphical autostart" (
      child.systemd.defaultUnit == "multi-user.target"
      && lib.elem "no-gui" child.system.nixos.tags
      && wants == [ "graphical.target" ]
      && child.services.greetd.enable
      && child.services.displayManager.noctalia-greeter.enable
      && child.programs.niri.enable
      && child.i18n.inputMethod.enable
      && child.services.getty.enable
      && lib.elem "getty@tty1.service" child.systemd.targets.getty.wants
    );

  # Ironbar and OmniWM are file-distribution Programs. This small harness checks
  # that both still work when explicitly selected, without evaluating unrelated
  # whole-host Home assertions or requiring another complete target evaluation.
  independentPrograms =
    (lib.evalModules {
      modules = [
        ../../modules/home/programs/ironbar
        ../../modules/home/programs/omniwm
        {
          options.xdg.configFile = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
          };
          config.dotfiles.programs = {
            ironbar.enable = true;
            omniwm.enable = true;
          };
        }
      ];
    }).config;

  independentXwayland =
    (self.nixosConfigurations.x86_64-linux-a--deployment-native--theme-dark--session-gui.extendModules {
      modules = [ { programs.xwayland.enable = true; } ];
    }).config.specialisation.no-gui.configuration;

  guiHomeCases = lib.filter (case: case.session == "gui") homeCases;
  guiHomes = map homeConfig guiHomeCases;
  guiSystems = map systemConfig (lib.filter (case: case.session == "gui") systemCases);
  # Niri's config renderer is a host-architecture derivation. Evaluate both
  # architectures above; only build rendered configs for this check's system.
  niriSources = lib.unique (
    map (case: (homeConfig case).xdg.configFile.niri.source) (
      lib.filter (case: lib.hasPrefix "${pkgs.stdenv.hostPlatform.system}-" case.host) guiHomeCases
    )
  );
  skkSources = lib.unique (map (config: config.xdg.configFile.libskk.source) guiHomes);
  profiles = lib.unique (map (config: config.environment.etc."xdg/fcitx5/profile".text) guiSystems);
  skkSettings = lib.unique (
    map (config: config.environment.etc."xdg/fcitx5/conf/skk.conf".text) guiSystems
  );
in
assert lib.all (case: checkHome (homeName case) case (homeConfig case)) homeCases;
assert lib.all checkSystem systemCases;
assert lib.all checkNoGui hosts;
assert expect "no-gui preserves an independent upstream Xwayland request" (
  independentXwayland.programs.xwayland.enable
  && independentXwayland.systemd.defaultUnit == "multi-user.target"
);
assert expect "explicit Ironbar selection distributes its config" (
  independentPrograms.xdg.configFile.ironbar.source == ../../modules/home/programs/ironbar/config
);
assert expect "explicit OmniWM selection distributes its config" (
  independentPrograms.xdg.configFile."omniwm/settings.toml".source
  == ../../modules/home/programs/omniwm/config/settings.toml
);
pkgs.runCommandLocal "session-gui-host-migration-test" { } ''
  ${lib.concatMapStringsSep "\n" (source: ''
    test -s ${lib.escapeShellArg "${source}/config.kdl"}
    grep -F 'spawn "noctalia" "msg"' ${lib.escapeShellArg "${source}/config.kdl"} >/dev/null
    test "$(grep -Fc 'spawn-at-startup "noctalia"' ${lib.escapeShellArg "${source}/config.kdl"})" -eq 1
  '') niriSources}
  ${lib.concatMapStringsSep "\n" (source: ''
    test -s ${lib.escapeShellArg "${source}/rules/custom/metadata.json"}
    test -s ${lib.escapeShellArg "${source}/rules/custom/keymap/default.json"}
    test -s ${lib.escapeShellArg "${source}/rules/custom/rom-kana/default.json"}
  '') skkSources}
  ${lib.concatMapStringsSep "\n" (text: ''
    grep -F 'Name=skk' ${pkgs.writeText "session-gui-input-profile" text} >/dev/null
  '') profiles}
  ${lib.concatMapStringsSep "\n" (text: ''
    grep -F 'Rule=custom' ${pkgs.writeText "session-gui-skk-settings" text} >/dev/null
  '') skkSettings}
  test -s ${independentPrograms.xdg.configFile.ironbar.source}/config.json
  test -s ${independentPrograms.xdg.configFile."omniwm/settings.toml".source}
  touch "$out"
''
