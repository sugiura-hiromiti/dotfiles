{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.emacs;
  configuredEmacsPackage = config.programs.emacs.package;
  emacsApp = "${configuredEmacsPackage}/Applications/Emacs.app";
  emacsAppExecutable = "${emacsApp}/Contents/MacOS/Emacs";
  emacsInitDirectory = "${config.xdg.configHome}/emacs";
  emacsClientBundleIdentifier = "org.nix-community.home.emacsclient";
  emacsClientDocumentTypes = [
    "public.plain-text"
    "public.source-code"
    "public.shell-script"
  ];
  emacsClientDocumentTypePlistEntries = lib.concatMapStringsSep "\n        " (
    contentType: "<string>${contentType}</string>"
  ) emacsClientDocumentTypes;
  emacsClientHandlerCommands = lib.concatMapStringsSep "\n" (
    contentType:
    "$DRY_RUN_CMD ${lib.getExe pkgs.duti} ${
      lib.escapeShellArgs [
        "-s"
        emacsClientBundleIdentifier
        contentType
        "all"
      ]
    }"
  ) emacsClientDocumentTypes;
  emacsClientLauncher = pkgs.writeShellScript "emacs-client-launcher" ''
    args=()
    for arg in "$@"; do
      case "$arg" in
        -psn_*) ;;
        *) args+=("$arg") ;;
      esac
    done

    if ! ${configuredEmacsPackage}/bin/emacsclient --eval '(emacs-pid)' >/dev/null 2>&1; then
      /usr/bin/nohup "${emacsAppExecutable}" "--init-directory=${emacsInitDirectory}" --fg-daemon >/dev/null 2>&1 &
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        ${configuredEmacsPackage}/bin/emacsclient --eval '(emacs-pid)' >/dev/null 2>&1 && break
        sleep 0.2
      done
    fi

    exec ${configuredEmacsPackage}/bin/emacsclient -n -c -F '((window-system . ns))' "''${args[@]}"
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
      <string>${emacsClientBundleIdentifier}</string>
      <key>CFBundleInfoDictionaryVersion</key>
      <string>6.0</string>
      <key>CFBundleName</key>
      <string>Emacs</string>
      <key>CFBundleDisplayName</key>
      <string>Emacs</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>CFBundleShortVersionString</key>
      <string>1.0</string>
      <key>CFBundleVersion</key>
      <string>1.0</string>
      <key>CFBundleDocumentTypes</key>
      <array>
        <dict>
          <key>CFBundleTypeName</key>
          <string>Text Document</string>
          <key>CFBundleTypeRole</key>
          <string>Editor</string>
          <key>LSHandlerRank</key>
          <string>Alternate</string>
          <key>LSItemContentTypes</key>
          <array>
            ${emacsClientDocumentTypePlistEntries}
          </array>
        </dict>
      </array>
      <key>LSMinimumSystemVersion</key>
      <string>10.13</string>
      <key>NSPrincipalClass</key>
      <string>NSApplication</string>
    </dict>
    </plist>
  '';
  emacsClientLauncherSource = pkgs.writeText "emacs-client-launcher.m" ''
    #import <AppKit/AppKit.h>

    #include <string.h>
    #include <unistd.h>

    @interface EmacsClientDelegate : NSObject <NSApplicationDelegate>
    @property BOOL handledOpen;
    @end

    @implementation EmacsClientDelegate

    - (BOOL)runLauncherWithArguments:(NSArray<NSString *> *)arguments {
      NSTask *task = [[NSTask alloc] init];
      task.executableURL = [NSURL fileURLWithPath:@"${emacsClientLauncher}"];
      task.arguments = arguments;

      NSError *error = nil;
      if (![task launchAndReturnError:&error]) {
        NSLog(@"Failed to launch Emacs client: %@", error);
        return NO;
      }

      [task waitUntilExit];
      return task.terminationStatus == 0;
    }

    - (void)application:(NSApplication *)application openFiles:(NSArray<NSString *> *)filenames {
      self.handledOpen = YES;
      BOOL succeeded = [self runLauncherWithArguments:filenames];
      [application replyToOpenOrPrint:(succeeded
        ? NSApplicationDelegateReplySuccess
        : NSApplicationDelegateReplyFailure)];
    }

    - (void)applicationDidFinishLaunching:(NSNotification *)notification {
      if (!self.handledOpen) {
        [self runLauncherWithArguments:@[]];
      }
      [NSApp terminate:nil];
    }

    @end

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

      if (out > 1) {
        execv(script, args);
        return 127;
      }

      @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        EmacsClientDelegate *delegate = [[EmacsClientDelegate alloc] init];
        application.delegate = delegate;
        [application run];
      }

      return 0;
    }
  '';
  emacsClientApp = pkgs.runCommandLocal "emacs-client-app" { } ''
    app="$out/Applications/Emacs.app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

    cp "${emacsApp}/Contents/Resources/Emacs.icns" "$app/Contents/Resources/Emacs.icns"
    cp "${emacsClientInfoPlist}" "$app/Contents/Info.plist"
    ${pkgs.stdenv.cc}/bin/cc -fobjc-arc -framework AppKit "${emacsClientLauncherSource}" -o "$app/Contents/MacOS/EmacsClient"
  '';
  lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";

in
lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isDarwin) {
  services = {
    emacs = {
      enable = lib.mkForce false;
      client.enable = lib.mkForce false;
    };
  };

  home = {
    activation = {
      registerEmacsApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        app_dir="$HOME/Applications/Home Manager Apps"

        $DRY_RUN_CMD mkdir -p "$app_dir"
        $DRY_RUN_CMD rm -rf "$app_dir/Emacs.app"
        $DRY_RUN_CMD ${pkgs.mkalias}/bin/mkalias "${emacsClientApp}/Applications/Emacs.app" "$app_dir/Emacs.app"
        $DRY_RUN_CMD ${lsregister} -u "${emacsApp}" || true
        $DRY_RUN_CMD ${lsregister} -f "${emacsClientApp}/Applications/Emacs.app"
        $DRY_RUN_CMD ${lsregister} -f "$app_dir/Emacs.app"
        ${emacsClientHandlerCommands}
      '';
    };
  };

  launchd = {
    agents = {
      emacs-app-daemon = {
        enable = true;
        config = {
          Label = "org.nix-community.home.emacs-app-daemon";
          ProgramArguments = [
            emacsAppExecutable
            "--init-directory=${emacsInitDirectory}"
            "--fg-daemon"
          ];
          RunAtLoad = true;
        };
      };
    };
  };
}
