{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.darwinApps;
in
{
  options.dotfiles.features.darwinApps = {
    enable = lib.mkEnableOption "Darwin desktop applications";

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = lib.optionals pkgs.stdenv.isDarwin [
        pkgs.betterdisplay
        pkgs.ghostty-bin
      ];
      defaultText = lib.literalExpression ''
        lib.optionals pkgs.stdenv.isDarwin [
          pkgs.betterdisplay
          pkgs.ghostty-bin
        ]
      '';
      description = "Darwin-specific Home Manager packages.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isDarwin;
        message = "dotfiles.features.darwinApps is Darwin-only.";
      }
    ];

    home.packages = cfg.packages;
  };
}
