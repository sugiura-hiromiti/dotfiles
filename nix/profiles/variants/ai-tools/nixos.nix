{ accounts, ... }:
let
  primaryUser = accounts.primary;
  primaryAccount = accounts.users.${primaryUser};
  homeDirectory =
    if primaryAccount.homeDirectory != null then
      primaryAccount.homeDirectory
    else
      "/home/${primaryUser}";
in
{
  programs.nix-agent = {
    enable = true;
    flake = "${homeDirectory}/dotfiles";
    privilegedAutomation = {
      enable = true;
      user = primaryUser;
    };
  };
}
