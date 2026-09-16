{ inputs, self }:
let
  inherit (inputs.nixpkgs) lib;
  runtimeContexts = import ../runtime-contexts.nix;
  targetNames = import ../lib/target-names.nix { inherit lib; };
  hostRegistry = import ../lib/hosts.nix {
    inherit lib runtimeContexts;
    hostDir = ../profiles/hosts;
  };
  inherit (hostRegistry) hosts hostNames;
  runtime = import ../lib/runtime.nix {
    inherit lib runtimeContexts;
  };
  targets = import ../lib/targets.nix {
    inherit
      lib
      hosts
      hostNames
      runtime
      targetNames
      ;
  };
  common = import ../configurations/common.nix {
    inherit lib;
    inherit (inputs) nix nix-agent;
  };
  home = import ../configurations/home.nix {
    inherit (inputs)
      nixpkgs
      nur
      home-manager
      catppuccin
      nix-index-database
      mcp-servers-nix
      i-have-adhd
      interview-me
      urd
      ;
    inherit (common) profileModules commonSpecialArgs;
  };
  nixos = import ../configurations/nixos.nix {
    inherit lib;
    inherit (inputs)
      nixpkgs
      disko
      preservation
      catppuccin
      nix-agent
      ;
    inherit (common) profileModules systemSpecialArgs;
  };
  darwin = import ../configurations/darwin.nix {
    inherit lib;
    inherit (inputs) nix-darwin;
    inherit (common) profileModules systemSpecialArgs;
  };
in
{
  systems = lib.unique (map (host: hosts.${host}.system) hostNames);
  imports = [
    (import ./configurations.nix {
      inherit (targets) mkTargetConfigs;
      inherit home nixos darwin;
    })
    (import ./formatting.nix {
      inherit (inputs) treefmt-nix;
    })
    (import ./apps.nix {
      inherit
        lib
        self
        hosts
        hostNames
        ;
      inherit (targets) mkTargetConfigEntries;
    })
    (import ./dev-shells.nix { inherit lib; })
    (import ./checks.nix {
      inherit lib self;
      inherit (inputs) disko preservation;
      inherit (targets) targetConfigNamesForSystem;
    })
    (import ./ci.nix {
      inherit lib hosts;
      inherit (targets) mkTargetConfigEntries;
      inherit (inputs) actions-nix;
    })
  ];
}
