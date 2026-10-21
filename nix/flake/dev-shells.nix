{ lib }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      formatters = import ../formatters { inherit lib pkgs; };
      repoMaintenancePackages = with pkgs; [
        formatters.editorTools
        deadnix
        nixd
        statix
        nodejs
        typescript
        typescript-language-server
        lua-language-server
        vscode-langservers-extracted
      ];
      nvimMaintenancePackages = with pkgs; [
        luajitPackages.luarocks
        tree-sitter
      ];
    in
    {
      devShells.default = pkgs.mkShell {
        name = "dotfiles-maintenance";
        inputsFrom = [ config.treefmt.build.devShell ];
        packages = repoMaintenancePackages;
      };
      devShells.nvim = pkgs.mkShell {
        name = "dotfiles-nvim";
        inputsFrom = [ config.treefmt.build.devShell ];
        packages = repoMaintenancePackages ++ nvimMaintenancePackages;
      };
    };
}
