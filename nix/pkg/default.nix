{ pkgs }:
with pkgs;
[
  lua5_4_compat
  lua-language-server
  luajitPackages.luarocks
  neovim
  rm-improved
  # skim # has hm and nushell plugin
  stylua
  plemoljp-nf
  tokei
  # yaml-language-server
  sd
  nil
  viu
  uv
  # vscode-langservers-extracted
  sqlite
  jq
  tree-sitter
  reaper
  gnumake
  # kitty
  nufmt
  bat
  wezterm
  gws
]
