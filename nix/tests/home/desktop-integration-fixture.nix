{
  lib,
  pkgs,
  home-manager,
}:
let
  hmLib = import "${home-manager}/modules/lib/stdlib-extended.nix" lib;
  hmModules = import "${home-manager}/modules/modules.nix" {
    inherit pkgs;
    lib = hmLib;
    useNixpkgsModule = false;
  };
in
feature: extra:
(hmLib.evalModules {
  class = "homeManager";
  specialArgs.modulesPath = "${home-manager}/modules";
  modules = hmModules ++ [
    ../../modules/home/features/desktop-integration.nix
    ../../modules/home/features/terminal.nix
    ../../modules/home/programs/kitty
    {
      home = {
        username = "desktop-integration-test";
        homeDirectory = "/home/desktop-integration-test";
        stateVersion = "26.05";
      };
      dotfiles.features = {
        terminal = {
          enable = lib.mkDefault true;
          provider = lib.mkDefault "kitty";
        };
        desktopIntegration = {
          mimeApps.enable = lib.mkDefault false;
          orgProtocol.enable = lib.mkDefault false;
        }
        // feature;
      };
    }
    extra
  ];
}).config
