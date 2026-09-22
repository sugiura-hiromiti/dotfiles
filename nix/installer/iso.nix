{
  nixpkgs,
  system,
  source,
  host,
  target,
  primaryAccount,
  facterRelativePath,
  extraModules ? [ ],
}:
nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
    (
      { lib, pkgs, ... }:
      let
        installer = (import ./script.nix { inherit lib pkgs; }) {
          inherit
            host
            target
            primaryAccount
            source
            facterRelativePath
            ;
          efiArch = lib.toUpper pkgs.stdenv.hostPlatform.efiArch;
        };
      in
      {
        networking.hostName = "dotfiles-installer";
        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];
        isoImage = {
          edition = lib.mkForce "dotfiles-${host}";
          volumeID = "DOTFILES_INSTALLER";
          storeContents = [ source ];
        };

        services.getty.autologinUser = lib.mkForce "root";
        systemd.services = {
          "getty@tty1".enable = false;
          "getty@tty2".wantedBy = [ "multi-user.target" ];
          dotfiles-installer = {
            description = "Install dotfiles for ${host}";
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            conflicts = [ "getty@tty1.service" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = toString installer;
              UMask = "0077";
              StandardInput = "tty-force";
              StandardOutput = "tty";
              StandardError = "tty";
              TTYPath = "/dev/tty1";
              TTYReset = true;
              TTYVHangup = true;
            };
          };
        };
      }
    )
  ]
  ++ extraModules;
}
