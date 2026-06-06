{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.emacs;
  emacsPackage = (pkgs.emacsPackagesFor pkgs.emacs-pgtk).emacsWithPackages (epkgs: [
    epkgs.tree-sitter-langs
    (epkgs.treesit-grammars.with-grammars (grammars: [
      grammars.tree-sitter-rust
      grammars.tree-sitter-typescript
      grammars.tree-sitter-haskell
      grammars.tree-sitter-toml
      grammars.tree-sitter-nu
      grammars.tree-sitter-csv
      grammars.tree-sitter-diff
      grammars.tree-sitter-gitcommit
      grammars.tree-sitter-gitignore
      grammars.tree-sitter-json
      grammars.tree-sitter-kdl
      grammars.tree-sitter-lua
      grammars.tree-sitter-markdown
      grammars.tree-sitter-markdown-inline
      grammars.tree-sitter-nix
      grammars.tree-sitter-sql
      grammars.tree-sitter-yaml
      grammars.tree-sitter-tsx
      grammars.tree-sitter-html
    ]))
  ]);
  configuredEmacsPackage = config.programs.emacs.package;
  emacsApp = "${configuredEmacsPackage}/Applications/Emacs.app";
  emacsAppExecutable = "${emacsApp}/Contents/MacOS/Emacs";
  emacsClientLauncher = pkgs.writeShellScript "emacs-client-launcher" ''
    args=()
    for arg in "$@"; do
      case "$arg" in
        -psn_*) ;;
        *) args+=("$arg") ;;
      esac
    done

    if ! ${configuredEmacsPackage}/bin/emacsclient --eval '(emacs-pid)' >/dev/null 2>&1; then
      /usr/bin/nohup "${emacsAppExecutable}" --fg-daemon >/dev/null 2>&1 &
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
  options.dotfiles.programs.emacs.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install and configure Emacs.";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.emacs = {
          enable = lib.mkDefault true;
          package = lib.mkDefault emacsPackage;
        };

        services.emacs = {
          enable = lib.mkDefault true;
          startWithUserSession = lib.mkDefault "graphical";
          client.enable = lib.mkDefault true;
          defaultEditor = lib.mkDefault true;
        };

        xdg.configFile = {
          "emacs/init.el".source = ./config/init.el;
          "emacs/early-init.el".source = ./config/early-init.el;
          "emacs/lisp" = {
            source = ./config/lisp;
            recursive = true;
          };
        };
      }

      (lib.mkIf pkgs.stdenv.isDarwin {
        services.emacs = {
          enable = lib.mkForce false;
          client.enable = lib.mkForce false;
        };

        home.activation.registerEmacsApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          app_dir="$HOME/Applications/Home Manager Apps"

          $DRY_RUN_CMD mkdir -p "$app_dir"
          $DRY_RUN_CMD rm -rf "$app_dir/Emacs.app"
          $DRY_RUN_CMD ${pkgs.mkalias}/bin/mkalias "${emacsClientApp}/Applications/Emacs.app" "$app_dir/Emacs.app"
          $DRY_RUN_CMD ${lsregister} -u "${emacsApp}" || true
          $DRY_RUN_CMD ${lsregister} -f "${emacsClientApp}/Applications/Emacs.app"
          $DRY_RUN_CMD ${lsregister} -f "$app_dir/Emacs.app"
        '';

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
      })
    ]
  );
}
