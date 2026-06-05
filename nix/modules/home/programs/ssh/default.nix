{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.ssh;
in
{
  options.dotfiles.programs.ssh.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the repository-managed OpenSSH client configuration.";
  };

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = [
        "~/.ssh/config.local"
      ];
      settings."github.personal" = {
        AddKeysToAgent = "yes";
        HostName = "ssh.github.com";
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = true;
        TCPKeepAlive = "yes";
        User = "git";
      };
    };
  };
}
