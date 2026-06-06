{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.darwin.power;
in
{
  options.dotfiles.darwin.power.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure baseline macOS power settings.";
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.pmset.text = ''
      /usr/bin/pmset -a womp 1
      /usr/bin/pmset -a powernap 1
    '';
  };
}
