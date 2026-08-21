{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.fish;
  sessionVariablesFile = "etc/profile.d/hm-session-vars.fish";
  sessionVariablesPackage = pkgs.runCommandLocal "dotfiles-hm-session-vars.fish" { } ''
    mkdir -p "$out/etc/profile.d"
    (
      echo "function setup_hm_session_vars;"
      ${pkgs.buildPackages.babelfish}/bin/babelfish \
        <${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh
      echo "end"
      echo "setup_hm_session_vars"
    ) >"$out/${sessionVariablesFile}"
  '';
  completionFiles = lib.attrNames (
    lib.filterAttrs (_: type: type == "regular") (builtins.readDir ./config/completions)
  );
  completionConfigFiles = lib.listToAttrs (
    map (name: {
      name = "fish/completions/${name}";
      value.source = ./config/completions + "/${name}";
    }) completionFiles
  );
in
{
  options.dotfiles.programs.fish.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to install the repository-managed Fish configuration.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile = {
      "fish/config.fish".source = ./config/config.fish;
      "fish/hm-session-vars.fish".source = "${sessionVariablesPackage}/${sessionVariablesFile}";
      "fish/conf.d" = {
        source = ./config/conf.d;
        recursive = true;
      };
      "fish/functions" = {
        source = ./config/functions;
        recursive = true;
      };
    }
    // completionConfigFiles;
  };
}
