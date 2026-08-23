{ lib, pkgs }: {
  mkGitHubAuthWrappedPackage =
    {
      package,
      tokenCommand,
      tokenEnvVar,
    }:
    let
      executable = package.meta.mainProgram;
      escapedTokenCommand = lib.escapeShellArgs tokenCommand;
      escapedTokenEnvVar = lib.escapeShellArg tokenEnvVar;
    in
    pkgs.symlinkJoin {
      pname = "${package.pname or executable}-with-github-token";
      version = lib.getVersion package;
      paths = [ package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram "$out/bin/${executable}" --run ${lib.escapeShellArg ''
          token_env_var=${escapedTokenEnvVar}
          if [ -z "$(printenv "$token_env_var")" ]; then
            token="$(${escapedTokenCommand})"
            export "$token_env_var=$token"
          fi
        ''}
      '';
      inherit (package) meta;
    };
  mkSerenaArgs =
    {
      packageSpec,
      context,
      projectFromCwd ? false,
    }:
    [
      "--from"
      packageSpec
      "serena"
      "start-mcp-server"
      "--context"
      context
    ]
    ++ lib.optionals projectFromCwd [ "--project-from-cwd" ];
}
