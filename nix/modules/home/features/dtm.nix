args@{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.dtm;
  systemDtm = args.osConfig.dotfiles.features.dtm or null;
in
{
  options.dotfiles.features.dtm = {
    enable = lib.mkEnableOption "digital music production tools";

    jack.enable = lib.mkOption {
      type = lib.types.bool;
      default =
        pkgs.stdenv.hostPlatform.isLinux
        && (systemDtm == null || (systemDtm.enable && systemDtm.jack.enable));
      defaultText = lib.literalExpression "the NixOS DTM JACK selection, or true on standalone Linux";
      description = ''
        Whether to provide pw-jack and use PipeWire's JACK libraries in enabled
        REAPER instances. Disabling stops this feature's JACK contributions;
        independently configured JACK support is preserved. This applies only
        on Linux.
      '';
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        dexed
      ];
      description = "DTM packages installed on every supported platform.";
    };

    linuxPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default =
        with pkgs;
        [
          geonkick
          synthv1
          lsp-plugins
          calf
          helm
          cardinal
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
          surge-xt
          vital
          bristol
        ];
      description = "DTM packages installed only on Linux.";
    };

    geonkick.enable = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.hostPlatform.isLinux;
      defaultText = lib.literalExpression "pkgs.stdenv.hostPlatform.isLinux";
      description = "Whether to install the repository-managed Geonkick configuration.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = !cfg.geonkick.enable || pkgs.stdenv.hostPlatform.isLinux;
            message = "dotfiles.features.dtm.geonkick is Linux-only.";
          }
        ];

        dotfiles.programs.reaper.enable = lib.mkDefault true;

        home.packages =
          cfg.packages
          ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux (
            cfg.linuxPackages ++ lib.optional cfg.jack.enable pkgs.pipewire.jack
          );
      }

      (lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && cfg.jack.enable && config.programs.reaper.enable) {
        programs.reaper.packages = [ pkgs.pipewire.jack ];
      })

      (lib.mkIf cfg.geonkick.enable {
        dotfiles.programs.geonkick.enable = true;
      })
    ]
  );
}
