{ lib, pkgs }: {
  mkGitHubAuthWrappedPackage =
    {
      package,
      tokenCommand,
      tokenEnvVar,
    }:
    let
      executable = package.meta.mainProgram;
    in
    pkgs.symlinkJoin {
      pname = "${package.pname or executable}-with-github-token";
      version = lib.getVersion package;
      paths = [ package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram "$out/bin/${executable}" --run ${lib.escapeShellArg ''
          token_env_var=${tokenEnvVar}
          if [ -z "$(printenv "$token_env_var")" ]; then
            token="$(${tokenCommand})"
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
