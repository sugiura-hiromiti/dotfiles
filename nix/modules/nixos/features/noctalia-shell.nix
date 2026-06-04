{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.dotfiles.features.noctaliaShell;
in
{
  options.dotfiles.features.noctaliaShell = {
    enable = mkEnableOption "Noctalia Shell";
    calendar.enable = mkEnableOption "Noctalia calendar integration";
    clipboard.enable = mkEnableOption "Noctalia clipboard history integration";
    ddc.enable = mkEnableOption "Noctalia DDC brightness integration";
    screenToolkit.enable = mkEnableOption "Noctalia screen toolkit plugin";
    visualizer.enable = mkEnableOption "Noctalia audio visualizer integration";
    wallpaper.enable = mkEnableOption "Noctalia wallpaper integration";
  };

  config = mkIf cfg.enable {
    services.gnome.evolution-data-server.enable = mkIf cfg.calendar.enable true;
  };
}
