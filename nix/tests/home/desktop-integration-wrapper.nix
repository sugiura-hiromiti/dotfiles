{
  lib,
  pkgs,
  home-manager,
}:
let
  evaluate = import ./desktop-integration-fixture.nix { inherit lib pkgs home-manager; };
  # Exercise the pinned upstream wrapper, replacing only the GUI processes.
  chooserPackage = pkgs.runCommandLocal "desktop-test-chooser" { } ''
    mkdir -p "$out/share/xdg-desktop-portal-termfilechooser"
    cp ${pkgs.xdg-desktop-portal-termfilechooser.src}/contrib/yazi-wrapper.sh \
      "$out/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh"
    substituteInPlace "$out/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh" \
      --replace-fail '#!/usr/bin/env sh' '#!${pkgs.runtimeShell}'
    chmod +x "$out/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh"
  '';
  terminalPackage = pkgs.writeShellScriptBin "selected-terminal" ''
    printf '%s\0' "$@" > "$TERMINAL_LOG"
    printf '%s' "$(command -v selected-terminal)" > "$TERMINAL_PATH_LOG"
    shift 2
    exec "$@"
  '';
  fileManagerPackage = pkgs.writeShellScriptBin "yazi" ''
    printf '%s\0' "$@" > "$YAZI_LOG"
    printf '%s' "$(command -v yazi)" > "$YAZI_PATH_LOG"
    for arg in "$@"; do
      case "$arg" in
        --chooser-file=*) chooser="''${arg#--chooser-file=}" ;;
        --cwd-file=*) cwd="''${arg#--cwd-file=}" ;;
      esac
    done
    if [ -n "''${cwd:-}" ]; then
      : > "$chooser"
      printf '%s\n' "$SELECTED_PATH" > "$cwd"
    else
      printf '%s\n' "$SELECTED_PATH" > "$chooser"
    fi
  '';
  configured =
    evaluate
      {
        enable = true;
        termfilechooser = {
          package = chooserPackage;
          fileManager.package = fileManagerPackage;
        };
      }
      {
        options.dotfiles.programs.recording.enable = lib.mkEnableOption "test terminal";
        config = {
          programs.yazi.enable = false;
          dotfiles.features.terminal.provider = "recording";
          dotfiles.terminalProviders.recording = {
            package = terminalPackage;
            appId = "test.terminal";
            mkCommand =
              {
                wait ? false,
                ...
              }:
              lib.escapeShellArgs [
                "selected-terminal"
                (if wait then "--wait" else "--no-wait")
                "title with 'quotes' and $literal"
              ];
          };
        };
      };
  configFile =
    pkgs.writeText "termfilechooser-config"
      configured.xdg.configFile."xdg-desktop-portal-termfilechooser/config".text;
  # Keep the real built-in command builders; replace only the GUI executable
  # with a process enforcing that terminal's child-command syntax.
  builtinTerminal =
    name:
    pkgs.writeShellScriptBin name ''
      if [ "''${NORMAL_LAUNCH:-0}" = 1 ]; then
        printf '%s\0' "$@" > "$NORMAL_ARGS"
        exit 0
      fi
      ${
        if name == "alacritty" then
          ''
            if [ "$1" != -e ]; then
              echo 'Alacritty requires -e before the child command' >&2
              exit 94
            fi
            shift
          ''
        else
          lib.optionalString (name == "wezterm") ''
            test "$1" = start
            test "$2" = --always-new-process
            shift 2
          ''
      }
      exec "$@"
    '';
  builtinPackages = lib.genAttrs [ "kitty" "alacritty" "wezterm" ] builtinTerminal;
  builtinEvaluate = import ./desktop-integration-fixture.nix {
    inherit lib home-manager;
    pkgs = pkgs // builtinPackages;
  };
  builtinConfigs = lib.mapAttrs (
    name: _:
    builtinEvaluate
      {
        enable = true;
        termfilechooser = {
          package = chooserPackage;
          fileManager.package = fileManagerPackage;
        };
      }
      {
        imports = [
          ../../modules/home/programs/alacritty
          ../../modules/home/programs/wezterm
        ];
        dotfiles.features.terminal.provider = name;
      }
  ) builtinPackages;
in
assert lib.all (entry: entry.assertion) configured.assertions;
assert lib.all (config: lib.all (entry: entry.assertion) config.assertions) (
  builtins.attrValues builtinConfigs
);
assert !configured.programs.yazi.enable;
pkgs.runCommandLocal "desktop-integration-wrapper-test" { nativeBuildInputs = [ pkgs.gnused ]; } ''
  wrapper=$(sed -n 's/^cmd=//p' ${configFile})
  export TERMINAL_LOG="$PWD/terminal-args"
  export TERMINAL_PATH_LOG="$PWD/terminal-path"
  export YAZI_LOG="$PWD/yazi-args"
  export YAZI_PATH_LOG="$PWD/yazi-path"
  export SELECTED_PATH="$PWD/selected 'file' with spaces"
  input="$PWD/input 'quoted' and \$literal"
  output="$PWD/output with spaces"

  for mode in open multiple directory save; do
    multiple=0 directory=0 save=0
    case "$mode" in
      multiple) multiple=1 ;;
      directory) directory=1 ;;
      save) save=1 ;;
    esac
    # The daemon's trailing argv must not override the selected provider.
    "$wrapper" "$multiple" "$directory" "$save" "$input" "$output" 0 \
      ${pkgs.runtimeShell} -c 'exit 93'
    printf '%s\0' --wait "title with 'quotes' and \$literal" yazi \
      "--chooser-file=$output" > expected-terminal
    printf '%s\0' "--chooser-file=$output" > expected-yazi
    if [ "$mode" = directory ]; then
      printf '%s\0' "--cwd-file=$output.1" >> expected-terminal
      printf '%s\0' "--cwd-file=$output.1" >> expected-yazi
      test ! -e "$output.1"
    fi
    printf '%s\0' "$input" >> expected-terminal
    printf '%s\0' "$input" >> expected-yazi
    cmp expected-terminal "$TERMINAL_LOG"
    cmp expected-yazi "$YAZI_LOG"
    test "$(cat "$TERMINAL_PATH_LOG")" = ${terminalPackage}/bin/selected-terminal
    test "$(cat "$YAZI_PATH_LOG")" = ${fileManagerPackage}/bin/yazi
    printf '%s\n' "$SELECTED_PATH" > expected-selection
    cmp expected-selection "$output"
  done
  ${lib.concatMapStringsSep "\n" (
    name:
    let
      config = builtinConfigs.${name};
      chooserConfig =
        pkgs.writeText "${name}-chooser-config"
          config.xdg.configFile."xdg-desktop-portal-termfilechooser/config".text;
      normalCommand = config.dotfiles.features.terminal.selected.mkCommand {
        appId = "class with spaces";
      };
      normalArgs = (lib.optional (name == "wezterm") "start") ++ [
        (if name == "kitty" then "--app-id" else "--class")
        "class with spaces"
      ];
    in
    ''
      wrapper=$(sed -n 's/^cmd=//p' ${chooserConfig})
      "$wrapper" 0 0 0 "$input" "$output" 0 ${pkgs.runtimeShell} -c 'exit 93'
      cmp expected-selection "$output"
      export NORMAL_ARGS="$PWD/${name}-normal-args"
      NORMAL_LAUNCH=1 ${normalCommand}
      printf '%s\0' ${lib.escapeShellArgs normalArgs} > expected-normal
      cmp expected-normal "$NORMAL_ARGS"
    ''
  ) (builtins.attrNames builtinConfigs)}
  touch "$out"
''
