{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.kitty;
  kitty = lib.getExe pkgs.kitty;
in
{
  options.dotfiles.programs.kitty.enable = lib.mkEnableOption "kitty terminal emulator";

  config = lib.mkMerge [
    {
      dotfiles = {
        terminalProviders =
          let
            customAppIdCommand = "${kitty} --app-id custom.term";
          in
          {
            kitty = {
              package = pkgs.kitty;
              command = lib.getExe pkgs.kitty;
              appId = "kitty";
              # TODO: 現在の設定ではfloating windowにしないapp idの管理場所が分散している為、統合する
              startupAppId = "custom.term";
              startupCommand = customAppIdCommand;
              keybindCommand = customAppIdCommand;
            };
          };
      };
    }
    (lib.mkIf cfg.enable {

      xdg.configFile."kitty" = {
        source = ./config;
        recursive = true;
      };
    })
  ];
}
