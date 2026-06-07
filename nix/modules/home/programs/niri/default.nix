{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.niri;
  paths = config.dotfiles.paths;
  niriConfig = pkgs.runCommandLocal "niri-config" { } ''
    mkdir -p "$out"
    cp -R "${./config}/." "$out/"
    chmod -R u+w "$out"
    substituteInPlace "$out/config.kdl" \
      --replace-fail "~/Downloads/media/screenshots" "${paths.screenshotDirectory}"
  '';
in
{
  options.dotfiles.programs.niri.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to install the repository-managed niri configuration.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."niri" = {
      source = niriConfig;
      recursive = true;
    };
  };
}
