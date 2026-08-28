{
  lib,
  pkgs,
}:
pkgs.python3Packages.buildPythonApplication {
  pname = "nix-agent";
  version = "0.11.0";
  format = "pyproject";

  src = pkgs.fetchFromGitHub {
    owner = "JEFF7712";
    repo = "nix-agent";
    rev = "38680524a3570b856eb00fc37c1f193213f169e7";
    hash = lib.fakeHash;
  };

  nativeBuildInputs =
    with pkgs.python3Packages;
    [
      setuptools
      wheel
    ]
    ++ [ pkgs.makeWrapper ];

  propagatedBuildInputs = with pkgs.python3Packages; [ fastmcp ];
  nativeCheckInputs = with pkgs.python3Packages; [ pytestCheckHook ];

  postFixup = ''
    wrapProgram "$out/bin/nix-agent" \
      --prefix PATH : "${
        lib.makeBinPath [
          pkgs.statix
          pkgs.deadnix
          pkgs.nixfmt
          pkgs.nvd
        ]
      }"
  '';

  meta = {
    description = "MCP server exposing composable NixOS and Home Manager operations";
    homepage = "https://github.com/JEFF7712/nix-agent";
    license = lib.licenses.mit;
    mainProgram = "nix-agent";
  };
}
