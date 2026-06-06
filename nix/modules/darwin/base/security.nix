{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.darwin.security;
in
{
  options.dotfiles.darwin.security.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure baseline sudo authentication.";
  };

  config = lib.mkIf cfg.enable {
    security.pam.services.sudo_local = {
      enable = lib.mkDefault true;
      touchIdAuth = lib.mkDefault true;
      watchIdAuth = lib.mkDefault true;
    };
  };
}
