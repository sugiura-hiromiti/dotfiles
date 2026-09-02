{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.aiTools;
  emacsEnabled = config.dotfiles.programs.emacs.enable;
  anvilStdioSource = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/zawatton/anvil.el/4306ea1058c6b7b659f2ac1f27426bfc1178eb5f/anvil-stdio.sh";
    hash = "sha256-Mpt83Cw/daNNbLVNJ42p86+e0tTDwxFs2GxVUfykK20=";
  };
  anvilRuntimePath = lib.makeBinPath [
    config.programs.emacs.package
    pkgs.coreutils
    pkgs.gawk
    pkgs.gnugrep
    pkgs.gnused
  ];
  anvilStdio = pkgs.writeShellScript "anvil-stdio.sh" ''
    export PATH=${lib.escapeShellArg anvilRuntimePath}:"$PATH"
    exec ${lib.getExe pkgs.bash} ${anvilStdioSource} "$@"
  '';
in
{
  config = lib.mkIf (cfg.enable && emacsEnabled) {
    xdg.configFile = {
      "emacs/lisp/init-anvil.el".source = ../../programs/emacs/config/lisp/init-anvil.el;
      "emacs/anvil-stdio.sh" = {
        source = anvilStdio;
        executable = true;
      };
    };
  };
}
