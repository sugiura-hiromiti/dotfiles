{
  git = {
    name = "sugiura-hiromiti";
    email = "pishadon57@gmail.com";
    includes = [ { path = "~/.github_auth"; } ];
  };

  jujutsu = {
    name = "sugiura-hiromiti";
    email = "pishadon57@gmail.com";
  };

  ssh = {
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
}
