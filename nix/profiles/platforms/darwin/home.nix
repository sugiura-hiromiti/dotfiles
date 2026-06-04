{
  pkgs,
  accountName,
  account ? { },
  lib,
  config,
  ...
}:
let
  configuredHomeDirectory = account.homeDirectory or null;
  homeDir =
    if configuredHomeDirectory != null then configuredHomeDirectory else "/Users/${accountName}";
  emacsPackage = config.programs.emacs.package;
  emacsApp = "${emacsPackage}/Applications/Emacs.app";
  emacsAppExecutable = "${emacsApp}/Contents/MacOS/Emacs";
  emacsClientLauncher = pkgs.writeShellScript "emacs-client-launcher" ''
    args=()
    for arg in "$@"; do
      case "$arg" in
        -psn_*) ;;
        *) args+=("$arg") ;;
      esac
    done

    if ! ${emacsPackage}/bin/emacsclient --eval '(emacs-pid)' >/dev/null 2>&1; then
      /usr/bin/nohup "${emacsAppExecutable}" --fg-daemon >/dev/null 2>&1 &
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        ${emacsPackage}/bin/emacsclient --eval '(emacs-pid)' >/dev/null 2>&1 && break
        sleep 0.2
      done
    fi

    exec ${emacsPackage}/bin/emacsclient -n -c -F '((window-system . ns))' "''${args[@]}"
  '';
  emacsClientInfoPlist = pkgs.writeText "emacs-client-Info.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleDevelopmentRegion</key>
      <string>English</string>
      <key>CFBundleExecutable</key>
      <string>EmacsClient</string>
      <key>CFBundleIconFile</key>
      <string>Emacs.icns</string>
      <key>CFBundleIdentifier</key>
      <string>org.nix-community.home.emacsclient</string>
      <key>CFBundleName</key>
      <string>Emacs</string>
      <key>CFBundleDisplayName</key>
      <string>Emacs</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>LSMinimumSystemVersion</key>
      <string>10.13</string>
    </dict>
    </plist>
  '';
  emacsClientLauncherSource = pkgs.writeText "emacs-client-launcher.c" ''
    #include <string.h>
    #include <unistd.h>

    int main(int argc, char **argv) {
      const char *script = "${emacsClientLauncher}";
      char *args[argc + 1];
      int out = 0;

      args[out++] = (char *)script;
      for (int i = 1; i < argc; i++) {
        if (strncmp(argv[i], "-psn_", 5) != 0) {
          args[out++] = argv[i];
        }
      }
      args[out] = 0;

      execv(script, args);
      return 127;
    }
  '';
  emacsClientApp = pkgs.runCommandLocal "emacs-client-app" { } ''
    app="$out/Applications/Emacs.app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

    cp "${emacsApp}/Contents/Resources/Emacs.icns" "$app/Contents/Resources/Emacs.icns"
    cp "${emacsClientInfoPlist}" "$app/Contents/Info.plist"
    ${pkgs.stdenv.cc}/bin/cc "${emacsClientLauncherSource}" -o "$app/Contents/MacOS/EmacsClient"
  '';
  lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";
in
{
  home = {
    homeDirectory = lib.mkDefault homeDir;
    sessionVariables.LIBSQLITE = "${pkgs.sqlite.out}/lib/libsqlite3.dylib";
    file = {

      "nushell_appsupport_config" = {
        target = "Library/Application Support/nushell/config.nu";
        source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/nushell/config.nu";
      };
    };
  };
  programs.nushell.environmentVariables.LIBSQLITE = "${pkgs.sqlite.out}/lib/libsqlite3.dylib";
  home.activation.registerEmacsApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    app_dir="$HOME/Applications/Home Manager Apps"

    $DRY_RUN_CMD mkdir -p "$app_dir"
    $DRY_RUN_CMD rm -rf "$app_dir/Emacs.app"
    $DRY_RUN_CMD ${pkgs.mkalias}/bin/mkalias "${emacsClientApp}/Applications/Emacs.app" "$app_dir/Emacs.app"
    $DRY_RUN_CMD ${lsregister} -u "${emacsApp}" || true
    $DRY_RUN_CMD ${lsregister} -f "${emacsClientApp}/Applications/Emacs.app"
    $DRY_RUN_CMD ${lsregister} -f "$app_dir/Emacs.app"
  '';
  home.packages = with pkgs; [
    # tart
    # raycast
    betterdisplay
    ghostty-bin
    # paneru.packages.${pkgs.system}.paneru
  ];
  services = {
    emacs = {
      enable = lib.mkForce false;
      client.enable = lib.mkForce false;
    };
    # paneru = {
    #   enable = true;
    #   settings = {
    #     options = {
    #       preset_column_widths = [
    #         0.3
    #         0.5
    #         0.7
    #         1.0
    #       ];
    #       # swipe_gesture_fingers = 4;
    #       # border_active_window = true;
    #     };
    #     swipe = {
    #       gesture = {
    #         fingers_count = 4;
    #         direction = "Natural";
    #       };
    #     };
    #     bindings = {
    #       window_focus_west = "cmd - h";
    #       window_focus_east = "cmd - l";
    #       window_focus_north = "cmd - j";
    #       window_focus_south = "cmd - k";
    #       window_swap_west = "cmd + ctrl - h";
    #       window_swap_east = "cmd + ctrl - l";
    #       window_swap_north = "cmd + ctrl - j";
    #       window_swap_south = "cmd + ctrl - k";
    #       window_center = "cmd + ctrl - c";
    #       window_resize = "cmd - r";
    #       window_manage = "cmd + ctrl - v";
    #       window_stack = "cmd - ;";
    #       window_unstack = "cmd - '";
    #       window_nextdisplay = "alt - a";
    #       mouse_nextdisplay = "alt + shift - a";
    #     };
    #     windows = {
    #       pip = {
    #         title = "Picture.*(in)?.*[Pp]icture";
    #         floating = true;
    #       };
    #     };
    #   };
    # };
  };
  launchd.agents.emacs-app-daemon = {
    enable = true;
    config = {
      Label = "org.nix-community.home.emacs-app-daemon";
      ProgramArguments = [
        emacsAppExecutable
        "--fg-daemon"
      ];
      RunAtLoad = true;
    };
  };
  # programs = {
  # };
}
