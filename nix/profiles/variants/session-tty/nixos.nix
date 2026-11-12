{ lib, ... }:
{
  systemd.defaultUnit = lib.mkDefault "multi-user.target";
}
