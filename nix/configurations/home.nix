{
  nixpkgs,
  glide,
  nur,
  home-manager,
  reaper-flake,
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
      reaperFlake = reaper-flake;
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
      glide.homeModules.default
      reaper-flake.homeModules.reaper
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
  overlays = commonOverlays;
  inherit
    build
    modulesFor
    pkgsFor
    specialArgsFor
    ;
}
