{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.dtm;
in
{
  options.dotfiles.features.dtm = {
    enable = lib.mkEnableOption "digital music production tools";

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        reaper
        dexed
      ];
      description = "DTM packages installed on every supported platform.";
    };

    linuxPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        geonkick
        synthv1
        lsp-plugins
        calf
        helm
        cardinal
      ];
      description = "DTM packages installed only on Linux.";
    };

    geonkick.enable = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.isLinux;
      defaultText = lib.literalExpression "pkgs.stdenv.isLinux";
      description = "Whether to install the repository-managed Geonkick configuration.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = !cfg.geonkick.enable || pkgs.stdenv.isLinux;
            message = "dotfiles.features.dtm.geonkick is Linux-only.";
          }
        ];

        home.packages = cfg.packages ++ lib.optionals pkgs.stdenv.isLinux cfg.linuxPackages;
      }

      (lib.mkIf cfg.geonkick.enable {
        dotfiles.programs.geonkick.enable = true;
      })
    ]
  );
}
