{
  lib,
  pkgs,
  home-manager,
}:
let
  evaluate =
    settings:
    (home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs.theme = "dark";
      modules = [
        ../../modules/home/base/paths.nix
        ../../modules/home/features/session-gui.nix
        ../../modules/home/features/noctalia-shell.nix
        ../../modules/home/features/osk.nix
        ../../modules/home/features/terminal.nix
        ../../modules/home/programs/alacritty
        ../../modules/home/programs/fcitx5
        ../../modules/home/programs/ironbar
        ../../modules/home/programs/libskk
        ../../modules/home/programs/niri
        ../../modules/home/programs/omniwm
        ../../modules/home/programs/wvkbd
        {
          home = {
            username = "session-gui-test";
            homeDirectory = "/home/session-gui-test";
            stateVersion = "26.05";
          };
          dotfiles.features.terminal.provider = lib.mkDefault "alacritty";
        }
        settings
      ];
    }).config;

  independentNiri = evaluate { dotfiles.programs.niri.enable = true; };
  disabled = evaluate { };
  feature = evaluate { dotfiles.features.sessionGui.enable = true; };
  shellFeature = evaluate {
    dotfiles.programs.niri.enable = true;
    dotfiles.features.noctaliaShell.enable = true;
  };
  overriddenShellFeature = evaluate {
    dotfiles.programs.niri.enable = true;
    dotfiles.features.noctaliaShell.enable = true;
    programs.noctalia.enable = lib.mkForce false;
  };
  directShell = evaluate {
    dotfiles.programs.niri.enable = true;
    programs.noctalia.enable = true;
  };
  systemdShell = evaluate {
    dotfiles.programs.niri.enable = true;
    programs.noctalia = {
      enable = true;
      systemd.enable = true;
    };
  };
  disabledIntegration = evaluate {
    dotfiles.programs.niri = {
      enable = true;
      noctalia.enable = false;
    };
    programs.noctalia.enable = true;
  };
  disabledStartup = evaluate {
    dotfiles.programs.niri = {
      enable = true;
      noctalia.startup.enable = false;
    };
    programs.noctalia.enable = true;
  };
  terminal = evaluate {
    dotfiles.programs.niri.enable = true;
    dotfiles.features.terminal = {
      enable = true;
      provider = "alacritty";
    };
  };
  shellWithoutTerminal = evaluate {
    dotfiles.programs.niri = {
      enable = true;
      terminal.enable = false;
    };
    programs.noctalia.enable = true;
  };
  shellWithTerminal = evaluate {
    dotfiles.programs.niri.enable = true;
    dotfiles.features.terminal = {
      enable = true;
      provider = "alacritty";
    };
    programs.noctalia.enable = true;
  };
  blockedNiri = evaluate {
    dotfiles.features.sessionGui.enable = true;
    dotfiles.programs.niri.enable = false;
  };
  blockedIntegration = evaluate {
    dotfiles.programs.niri = {
      enable = true;
      noctalia.enable = true;
    };
  };
  niriOwners = [
    {
      name = "sessionGui Feature";
      settings.dotfiles.features.sessionGui.enable = true;
    }
    {
      name = "direct Niri Program";
      settings.dotfiles.programs.niri.enable = true;
    }
  ];
  blockedDeployments = lib.concatMap (owner: [
    {
      name = "${owner.name} with xdg.configFile.niri.enable = false";
      config = evaluate {
        config = lib.mkMerge [
          owner.settings
          { xdg.configFile.niri.enable = false; }
        ];
      };
    }
    {
      name = "${owner.name} with a disabled backing home.file";
      config = evaluate {
        config = lib.mkMerge [
          owner.settings
          { home.file."/home/session-gui-test/.config/niri".enable = lib.mkForce false; }
        ];
      };
    }
  ]) niriOwners;
  customNiriSource = pkgs.writeTextDir "config.kdl" "// Custom Niri configuration\n";
  customDeployments = map (owner: {
    name = "${owner.name} with a custom XDG_CONFIG_HOME and Niri source";
    config = evaluate {
      config = lib.mkMerge [
        owner.settings
        {
          xdg.configHome = "/home/session-gui-test/custom-config";
          xdg.configFile.niri.source = lib.mkForce customNiriSource;
        }
      ];
    };
  }) niriOwners;
  sharedPrograms = evaluate {
    dotfiles.features.sessionGui.enable = false;
    dotfiles.programs = {
      niri.enable = true;
      fcitx5.enable = true;
      fcitx5.packages = [ pkgs.hello ];
      ironbar.enable = true;
      libskk.enable = true;
      omniwm.enable = true;
    };
    programs.noctalia.enable = true;
  };
  unsupportedSession =
    builtins.tryEval
      (evaluate {
        dotfiles.features.sessionGui.session = "unsupported";
      }).dotfiles.features.sessionGui.session;

  generated = config: "${config.xdg.configFile.niri.source}/config.kdl";
  valid = config: lib.all (item: item.assertion) config.assertions;
  evaluationCases = [
    (lib.assertMsg (valid disabled) "disabled feature: Home Manager assertions failed")
    (lib.assertMsg (
      !disabled.dotfiles.programs.niri.enable && !(disabled.xdg.configFile ? niri)
    ) "disabled feature unexpectedly configures Niri")
    (lib.assertMsg (
      feature.dotfiles.programs.niri.enable && feature.xdg.configFile ? niri
    ) "sessionGui failed to provide Niri user configuration")
    (lib.assertMsg (lib.all (program: !feature.dotfiles.programs.${program}.enable) [
      "fcitx5"
      "ironbar"
      "libskk"
      "omniwm"
    ]) "sessionGui unexpectedly requires independent input method or panel Programs")
    (lib.assertMsg (
      !(lib.elem (toString pkgs.xwayland-satellite) (map toString feature.home.packages))
    ) "sessionGui unexpectedly owns Xwayland Satellite installation")
    (lib.assertMsg (
      feature.dotfiles.features.sessionGui.session == "niri"
    ) "sessionGui did not select its Niri default")
    (lib.assertMsg (
      !(builtins.tryEval (valid blockedNiri)).success
    ) "sessionGui accepted an effectively disabled Niri Program")
    (lib.assertMsg (
      !(builtins.tryEval (valid blockedIntegration)).success
    ) "Niri accepted explicit Noctalia integration with a disabled Shell")
    (lib.assertMsg (!unsupportedSession.success) "sessionGui accepted an unsupported session")
    (lib.assertMsg (valid sharedPrograms) "disabled sessionGui blocks independently enabled Programs")
    (lib.assertMsg (
      sharedPrograms.dotfiles.programs.niri.enable
      && sharedPrograms.programs.noctalia.enable
      && sharedPrograms.xdg.configFile ? ironbar
      && sharedPrograms.xdg.configFile ? libskk
      && sharedPrograms.xdg.configFile ? "omniwm/settings.toml"
      && lib.elem (toString pkgs.hello) (map toString sharedPrograms.home.packages)
    ) "disabled sessionGui lost another consumer's Program configuration")
    (lib.assertMsg (
      systemdShell.systemd.user.services ? noctalia
    ) "systemd Shell test did not activate the upstream autostart service")
  ]
  ++ map (
    case:
    lib.assertMsg (
      !(builtins.tryEval (valid case.config)).success
    ) "${case.name}: Niri accepted disabled configuration deployment"
  ) blockedDeployments
  ++ map (
    case:
    lib.assertMsg (
      valid case.config
      && case.config.home.file."/home/session-gui-test/custom-config/niri".enable
      && case.config.home.file."/home/session-gui-test/custom-config/niri".source == customNiriSource
    ) "${case.name}: Niri rejected valid deployment customization"
  ) customDeployments;
  artifactCases = [
    {
      name = "independent Niri without Shell";
      config = independentNiri;
      shell = false;
      startup = false;
      terminal = false;
    }
    {
      name = "Session feature without Shell";
      config = feature;
      shell = false;
      startup = false;
      terminal = false;
    }
    {
      name = "Shell feature";
      config = shellFeature;
      shell = true;
      startup = true;
      terminal = false;
    }
    {
      name = "Shell feature respects an effective Program disable";
      config = overriddenShellFeature;
      shell = false;
      startup = false;
      terminal = false;
    }
    {
      name = "direct shared Shell Program";
      config = directShell;
      shell = true;
      startup = true;
      terminal = false;
    }
    {
      name = "systemd Shell startup";
      config = systemdShell;
      shell = true;
      startup = false;
      terminal = false;
    }
    {
      name = "explicit integration opt-out";
      config = disabledIntegration;
      shell = false;
      startup = false;
      terminal = false;
    }
    {
      name = "startup opt-out retains IPC";
      config = disabledStartup;
      shell = true;
      startup = false;
      terminal = false;
    }
    {
      name = "Terminal remains independent without Shell";
      config = terminal;
      shell = false;
      startup = false;
      terminal = true;
    }
    {
      name = "Shell remains independent without Terminal";
      config = shellWithoutTerminal;
      shell = true;
      startup = true;
      terminal = false;
    }
    {
      name = "Shell and Terminal together";
      config = shellWithTerminal;
      shell = true;
      startup = true;
      terminal = true;
    }
  ];
  artifactCheck =
    case:
    assert lib.assertMsg (valid case.config) "${case.name}: Home Manager assertion failed";
    ''
      echo ${lib.escapeShellArg case.name}
      config=${lib.escapeShellArg (generated case.config)}
      ${if case.startup then "once" else "absent"} 'spawn-at-startup "noctalia"'
      ${if case.shell then "present" else "absent"} 'spawn "noctalia" "msg"'
      ${lib.optionalString case.shell ''
        present 'Mod+Space repeat=false { spawn "noctalia" "msg" "panel-toggle" "launcher"; }'
        present 'Mod+C repeat=false { spawn "noctalia" "msg" "panel-toggle" "clipboard"; }'
        present 'Mod+Escape repeat=false { spawn "noctalia" "msg" "panel-toggle" "session"; }'
        present 'Mod+N { spawn "noctalia" "msg" "notification-clear-active"; }'
        present 'XF86AudioRaiseVolume allow-when-locked=true { spawn "noctalia" "msg" "volume-up"; }'
        present 'XF86AudioLowerVolume allow-when-locked=true { spawn "noctalia" "msg" "volume-down"; }'
        present 'Shift+XF86AudioRaiseVolume allow-when-locked=true { spawn "noctalia" "msg" "mic-volume-up"; }'
        present 'Shift+XF86AudioLowerVolume allow-when-locked=true { spawn "noctalia" "msg" "mic-volume-down"; }'
        present 'XF86MonBrightnessUp   allow-when-locked=true { spawn "noctalia" "msg" "brightness-up"; }'
        present 'XF86MonBrightnessDown allow-when-locked=true { spawn "noctalia" "msg" "brightness-down"; }'
      ''}
      ${if case.terminal then "present" else "absent"} 'Open a Terminal'
      ${if case.terminal then "present" else "absent"} 'dotfiles.terminal.tiled'
      ${if case.terminal then "present" else "absent"} 'spawn-at-startup "sh" "-lc"'
      ${if case.terminal then "present" else "absent"} 'match app-id="^Alacritty$"'
      absent '@terminalStartup@'
      absent '@terminalKeybind@'
      absent '@floatingTerminalWindowRule@'
      absent '@noctaliaStartup@'
      absent '@noctaliaKeybinds@'
    '';
in
assert lib.all (result: result) evaluationCases;
pkgs.runCommandLocal "session-gui-home-test" { } ''
  once() {
    present "$1"
    test "$(grep -Fc -- "$1" "$config")" -eq 1
  }
  present() {
    if ! grep -Fq -- "$1" "$config"; then
      echo "Missing expected Niri configuration: $1" >&2
      exit 1
    fi
  }
  absent() {
    if grep -Fq -- "$1" "$config"; then
      echo "Unexpected Niri configuration: $1" >&2
      exit 1
    fi
  }
  ${lib.concatMapStringsSep "\n" artifactCheck artifactCases}
  touch "$out"
''
