{ treefmt-nix }:
{
  imports = [ treefmt-nix.flakeModule ];
  perSystem = {
    treefmt.imports = [ ../treefmt.nix ];
  };
}
