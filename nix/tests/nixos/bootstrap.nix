{
  lib,
  pkgs,
  disko,
  preservation,
}:
let
  evaluate =
    extra:
    lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        (import ../../configurations/nixos-bootstrap.nix {
          inherit disko preservation;
          hostConfig = {
            accounts.primary = "admin";
            facterPath = ../../profiles/hosts/aarch64-linux-a/facter.json;
          };
        })
        {
          users.users.admin = {
            isNormalUser = true;
            uid = 1234;
            group = "staff";
            home = "/srv/admin";
            extraGroups = [ "wheel" ];
          };
          users.groups.staff.gid = 2345;
        }
        extra
      ];
    };
  system = evaluate { };
  metadata = system.config.dotfiles.installer.metadata;
  rejects =
    extra:
    !(builtins.tryEval (builtins.deepSeq (evaluate extra).config.dotfiles.installer.metadata true))
    .success;
in
assert metadata.primaryUser.uid == 1234;
assert metadata.primaryUser.gid == 2345;
assert metadata.primaryUser.home == "/srv/admin";
assert metadata.primaryUser.hashedPasswordFile == "/persist/etc/dotfiles/password-admin.hash";
assert metadata.preservation.backingPath == "/persist/srv/admin/dotfiles";
assert metadata.preservation.runtimePath == "/srv/admin/dotfiles";
assert metadata.boot.systemdBoot && !metadata.boot.canTouchEfiVariables;
assert !metadata.mutableUsers && metadata.sudoEnabled;
assert
  system.config.boot.initrd.systemd.tmpfiles.settings.preservation."/sysroot/persist/etc".d.mode
  == "0755";
assert
  system.config.systemd.services.systemd-machine-id-commit.unitConfig.ConditionPathIsMountPoint == [
    ""
    "/persist/etc/machine-id"
  ];
assert
  system.config.systemd.services.systemd-machine-id-commit.serviceConfig.ExecStart == [
    ""
    "systemd-machine-id-setup --commit --root /persist"
  ];
assert rejects { users.mutableUsers = lib.mkForce true; };
assert rejects { users.users.admin.home = lib.mkForce "/srv/../admin"; };
assert rejects { users.users.admin.home = lib.mkForce "/"; };
assert rejects { users.users.admin.extraGroups = lib.mkForce [ ]; };
assert rejects { security.sudo.enable = lib.mkForce false; };
assert rejects { boot.loader.efi.canTouchEfiVariables = lib.mkForce true; };
assert rejects { users.users.admin.hashedPasswordFile = lib.mkForce "/wrong"; };
assert rejects { preservation.preserveAt."/persist".users.admin.directories = lib.mkForce [ ]; };
pkgs.runCommandLocal "bootstrap-eval-test" { } ''touch "$out"''
