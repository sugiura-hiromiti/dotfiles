{
  nixpkgs,
  nur,
  home-manager,
  catppuccin,
  nix-index-database,
  mcp-servers-nix,
  i-have-adhd,
  interview-me,
  urd,
  profileModules,
  commonSpecialArgs,
}:
let
  commonOverlays = [
    nur.overlays.default
  ];
  pkgsFor =
    system:
    import nixpkgs {
      inherit system;
      overlays = commonOverlays;
    };
  specialArgsFor =
    config:
    commonSpecialArgs config
    // {
      iHaveAdhdSkill = i-have-adhd.outPath;
      interviewMeSkill = interview-me.outPath;
      urdSkill = urd.outPath;
    };
  modulesFor =
    config:
    [ ../home ]
    ++ profileModules "home" config
    ++ [
      catppuccin.homeModules.catppuccin
      nix-index-database.homeModules.default
      mcp-servers-nix.homeManagerModules.default
    ];
  build =
    config:
    home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsFor config.system;
      extraSpecialArgs = specialArgsFor config;
      modules = modulesFor config;
    };
in
{
  inherit
    build
    modulesFor
    pkgsFor
    specialArgsFor
    ;
}
