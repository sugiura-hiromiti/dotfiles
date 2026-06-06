{
  lib,
  pkgs,
  system,
  currentSystemHosts,
  currentSystemAccounts,
  currentSystemHostAliases,
  currentSystemHostDefaultSessions,
  validThemes,
  validSessions,
  homeTargets,
  nixosTargets,
  darwinTargets,
}:
let
  validHostsArgs = lib.escapeShellArgs currentSystemHosts;
  validAccountsArgs = lib.escapeShellArgs currentSystemAccounts;
  validThemesArgs = lib.escapeShellArgs validThemes;
  validSessionsArgs = lib.escapeShellArgs validSessions;
  validHomeTargetsArgs = lib.escapeShellArgs homeTargets;
  validNixosTargetsArgs = lib.escapeShellArgs nixosTargets;
  validDarwinTargetsArgs = lib.escapeShellArgs darwinTargets;
  validHostsText = lib.concatStringsSep ", " currentSystemHosts;
  validAccountsText = lib.concatStringsSep ", " currentSystemAccounts;
  validThemesText = lib.concatStringsSep ", " validThemes;
  validSessionsText = lib.concatStringsSep ", " validSessions;
  hostDefaultSessionCases = lib.concatStringsSep "\n" (
    map (host: ''
      ${lib.escapeShellArg host})
        printf '%s\n' ${lib.escapeShellArg currentSystemHostDefaultSessions.${host}}
        return 0
        ;;
    '') currentSystemHosts
  );
  hostAliasCases = lib.concatStringsSep "\n" (
    lib.flatten (
      map (
        host:
        map (alias: ''
          ${lib.escapeShellArg alias})
            printf '%s\n' ${lib.escapeShellArg host}
            return 0
            ;;
        '') currentSystemHostAliases.${host}
      ) currentSystemHosts
    )
  );
in
{
  type = "app";
  meta.description = "Update flake inputs and switch the current host configuration";
  program = toString (
    pkgs.writeShellScript "update-script" ''
      set -eu

      usage() {
        cat <<EOF
      usage: nix run path:.#update -- [--host HOST] [--account ACCOUNT] [--theme THEME] [--session SESSION] [--system-session SESSION]
      home target: HOST--account-ACCOUNT--theme-THEME--session-SESSION
      system target: HOST--theme-THEME--session-SYSTEM_SESSION
      valid hosts: ${validHostsText}
      valid accounts: ${validAccountsText}
      valid themes: ${validThemesText}
      valid sessions: ${validSessionsText}
      EOF
      }

      is_member() {
        needle="$1"
        shift
        for item in "$@"; do
          if [ "$needle" = "$item" ]; then
            return 0
          fi
        done
        return 1
      }

      detect_host() {
        for candidate in \
          "''${DOTFILES_HOST:-}" \
          "$(hostname -s 2>/dev/null || true)" \
          "$(hostname 2>/dev/null || true)" \
          "${system}-$target_account"
        do
          if [ -z "$candidate" ]; then
            continue
          fi

          case "$candidate" in
      ${hostAliasCases}
          esac
        done

        echo "could not detect host for ${system}; pass --host explicitly" >&2
        return 1
      }

      default_session_for_host() {
        case "$1" in
      ${hostDefaultSessionCases}
        esac

        echo "could not find default session for host: $1" >&2
        return 1
      }

      target_host=""
      target_account=""
      theme=""
      session=""
      system_session=""
      flake_ref="path:$(pwd -P)"

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --host)
            if [ "$#" -lt 2 ]; then
              echo "missing value for --host" >&2
              usage >&2
              exit 2
            fi
            target_host="$2"
            shift 2
            ;;
          --account)
            if [ "$#" -lt 2 ]; then
              echo "missing value for --account" >&2
              usage >&2
              exit 2
            fi
            target_account="$2"
            shift 2
            ;;
          --theme)
            if [ "$#" -lt 2 ]; then
              echo "missing value for --theme" >&2
              usage >&2
              exit 2
            fi
            theme="$2"
            shift 2
            ;;
          --session)
            if [ "$#" -lt 2 ]; then
              echo "missing value for --session" >&2
              usage >&2
              exit 2
            fi
            session="$2"
            shift 2
            ;;
          --system-session)
            if [ "$#" -lt 2 ]; then
              echo "missing value for --system-session" >&2
              usage >&2
              exit 2
            fi
            system_session="$2"
            shift 2
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          *)
            echo "unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
          esac
      done

      if [ -z "$target_account" ]; then
        target_account="$(id -un)"
      fi

      if [ -z "$target_host" ]; then
        target_host="$(detect_host)"
      fi

      if [ -z "$theme" ]; then
        hour="$(date +%H)"
        hour="$((10#$hour))"
        if [ "$hour" -gt 5 ] && [ "$hour" -lt 17 ]; then
          theme="light"
        else
          theme="dark"
        fi
      fi

      if [ -z "$session" ]; then
        if [ -n "''${WAYLAND_DISPLAY:-}" ] || [ -n "''${DISPLAY:-}" ]; then
          session="gui"
        else
          session="tty"
        fi
      fi

      if ! is_member "$target_host" ${validHostsArgs}; then
        echo "unknown host for ${system}: $target_host" >&2
        usage >&2
        exit 2
      fi

      if ! is_member "$target_account" ${validAccountsArgs}; then
        echo "unknown account for ${system}: $target_account" >&2
        usage >&2
        exit 2
      fi

      if ! is_member "$theme" ${validThemesArgs}; then
        echo "unknown theme: $theme" >&2
        usage >&2
        exit 2
      fi

      if ! is_member "$session" ${validSessionsArgs}; then
        echo "unknown session: $session" >&2
        usage >&2
        exit 2
      fi

      if [ -z "$system_session" ]; then
        system_session="$(default_session_for_host "$target_host")"
      fi

      if ! is_member "$system_session" ${validSessionsArgs}; then
        echo "unknown system session: $system_session" >&2
        usage >&2
        exit 2
      fi

      home_target="$target_host--account-$target_account--theme-$theme--session-$session"
      system_target="$target_host--theme-$theme--session-$system_session"

      if ! is_member "$home_target" ${validHomeTargetsArgs}; then
        echo "home configuration is not defined: $home_target" >&2
        exit 2
      fi

      system_switch=""
      if [ "$(uname)" = "Darwin" ]; then
        if is_member "$system_target" ${validDarwinTargetsArgs}; then
          system_switch="darwin"
        fi
      elif [ -r /etc/os-release ] && grep -qi nixos /etc/os-release; then
        if is_member "$system_target" ${validNixosTargetsArgs}; then
          system_switch="nixos"
        fi
      fi

      if [ -n "$system_switch" ]; then
        sudo -v
      fi

      nix flake update --flake "$flake_ref"
      git stage flake.lock

      nix eval --raw "$flake_ref#homeConfigurations.\"$home_target\".activationPackage.drvPath" >/dev/null
      nix run nixpkgs#home-manager -- switch --flake "$flake_ref#$home_target"

      case "$system_switch" in
        darwin)
          sudo nix run nix-darwin -- switch --flake "$flake_ref#$system_target"
          ;;
        nixos)
          sudo nixos-rebuild switch --flake "$flake_ref#$system_target"
          ;;
      esac
    ''
  );
}
