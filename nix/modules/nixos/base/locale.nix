{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.nixos.locale;
in
{
  options.dotfiles.nixos.locale.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure baseline locale and timezone settings.";
  };

  config = lib.mkIf cfg.enable {
    time.timeZone = lib.mkDefault "Asia/Tokyo";

    i18n = {
      defaultLocale = lib.mkDefault "en_US.UTF-8";
      extraLocaleSettings = {
        LC_ADDRESS = "en_US.UTF-8";
        LC_IDENTIFICATION = "en_US.UTF-8";
        LC_MEASUREMENT = "en_US.UTF-8";
        LC_MONETARY = "en_US.UTF-8";
        LC_NAME = "en_US.UTF-8";
        LC_NUMERIC = "en_US.UTF-8";
        LC_PAPER = "en_US.UTF-8";
        LC_TELEPHONE = "en_US.UTF-8";
        LC_TIME = "en_US.UTF-8";
      };
    };
  };
}
