{
  account ? { },
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.programs.ssh;
  sshAccount = account.ssh or { };
in
{
  options.dotfiles.programs.ssh.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to install the repository-managed OpenSSH client configuration.";
  };

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = sshAccount.includes or [ ];
      settings = sshAccount.settings or { };
    };
  };
}
