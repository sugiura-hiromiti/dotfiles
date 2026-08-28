{
  accounts,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.nixAgent;
  primaryUser = accounts.primary;
  primaryAccount = accounts.users.${primaryUser};
  homeDirectory = primaryAccount.homeDirectory or "/home/${primaryUser}";
  flakeDirectory = "${homeDirectory}/dotfiles";
  nixAgentPackage = import ../../../pkg/nix-agent.nix { inherit lib pkgs; };
  nixosRebuild = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
  nixEnv = "${pkgs.nix}/bin/nix-env";
in
{
  options.dotfiles.features.nixAgent.enable =
    lib.mkEnableOption "privileged nix-agent MCP automation";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ nixAgentPackage ];

    security.sudo.extraRules = [
      {
        users = [ primaryUser ];
        commands = [
          {
            command = "${nixosRebuild} dry-activate --flake ${flakeDirectory}*";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${nixosRebuild} switch --flake ${flakeDirectory}*";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${nixosRebuild} switch --rollback";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${nixEnv} -p /nix/var/nix/profiles/system --switch-generation *";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/nix/var/nix/profiles/system/bin/switch-to-configuration switch";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
