{ targetConfig }:
{
  environment.etc."dotfiles/identity.json".text = builtins.toJSON {
    inherit (targetConfig) host;
    deployment = targetConfig.deploymentName;
  };
}
