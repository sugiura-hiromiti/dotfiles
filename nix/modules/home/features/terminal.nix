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
          package = lib.mkOption { type = lib.types.package; };
          appId = lib.mkOption { type = lib.types.str; };
          mkCommand = lib.mkOption {
            type = lib.types.functionTo lib.types.str;
            description = ''
              Build a shell-escaped terminal command. Accepts appId (optional
              window identity), wait (keep the launch in the foreground), and
              withCommand (prepare for child command argv appended by the caller).
              withCommand defaults to false for ordinary interactive launches.
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
