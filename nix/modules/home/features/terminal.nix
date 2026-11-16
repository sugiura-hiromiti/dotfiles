{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.features.terminal;
in
{
  options =
    let
      terminalProviderModule = lib.types.submodule {
        options = {
          package = lib.mkOption {
            type = lib.types.package;
            description = ''
              Terminal package installed by this feature. mkCommand must derive
              its executable from this provider's final package value.
            '';
          };
          appId = lib.mkOption { type = lib.types.str; };
          mkCommand = lib.mkOption {
            type = lib.types.functionTo lib.types.str;
            description = ''
              Build a shell-escaped command using this provider's final package.
              Accepts appId (window identity, default null), wait (default false),
              and withCommand (default false). When wait is true, the launcher
              must not exit before the terminal's child command finishes; false
              does not require detaching. When withCommand is true, the command
              must accept child program argv appended by the caller. Ordinary
              interactive launches omit child-command-only flags.
              The function type checks the return value, not these semantics;
              providers must satisfy the same command contract.
            '';
          };
        };
      };
      roleOption = lib.types.submodule {
        options = {
          appId = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };
      };
    in
    {
      dotfiles = {
        terminalProviders = lib.mkOption {
          type = lib.types.attrsOf terminalProviderModule;
          default = { };
        };
        features = {
          terminal = {
            enable = lib.mkEnableOption "terminal emulator";
            provider = lib.mkOption {
              type = lib.types.str;
              description = "terminal provider to use";
            };
            selected = lib.mkOption {
              type = terminalProviderModule;
              readOnly = true;
            };
            role = {
              tiled = lib.mkOption {
                type = roleOption;
                readOnly = true;
              };
              floating = lib.mkOption {
                type = roleOption;
                readOnly = true;
              };
            };
          };
        };
      };
    };

  config =
    let
      providers = config.dotfiles.terminalProviders;
      selected = providers.${cfg.provider} or null;
    in
    lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = selected != null;
          message = "unknown terminal provider: ${cfg.provider}";
        }
      ];
      dotfiles = {
        programs = lib.setAttrByPath [ cfg.provider "enable" ] true;
        features = {
          terminal = {
            inherit selected;
            role = {
              tiled = {
                appId = "dotfiles.terminal.tiled";
              };
              floating = {
                inherit (selected) appId;
              };
            };
          };
        };
      };
      home = {
        packages = [ selected.package ];
      };
    };
}
