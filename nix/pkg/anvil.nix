{
  lib,
  pkgs,
  emacsPackage,
}:
let
  python = pkgs.python3.withPackages (ps: with ps; [
    openpyxl
    pymupdf
  ]);

  runtimePackages =
    with pkgs;
    [
      agent-browser
      bash
      coreutils
      curl
      fd
      gawk
      git
      gnugrep
      gnused
      jq
      nodejs
      ripgrep
      sqlite
      tmux
      which
      python
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ procps ];

  runtimePath = lib.makeBinPath ([ emacsPackage ] ++ runtimePackages);
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "anvil-el";
  version = "1.3.0-unstable-2026-08-04";

  src = pkgs.fetchFromGitHub {
    owner = "zawatton";
    repo = "anvil.el";
    rev = "22d8f8a7bf5a2029dee448ba1c411fffeac42a14";
    hash = lib.fakeHash;
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/anvil" "$out/bin"
    cp -a . "$out/share/anvil/"

    makeWrapper ${pkgs.bash}/bin/bash "$out/bin/anvil-stdio" \
      --add-flags "$out/share/anvil/anvil-stdio.sh" \
      --prefix PATH : "${runtimePath}"

    runHook postInstall
  '';

  passthru = {
    inherit runtimePackages;
  };

  meta = {
    description = "Emacs MCP workbench for AI agents";
    homepage = "https://github.com/zawatton/anvil.el";
    license = lib.licenses.gpl3Plus;
    mainProgram = "anvil-stdio";
  };
}
