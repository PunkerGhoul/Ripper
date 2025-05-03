{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    plugins = let
      nvim-treesitter-with-plugins = pkgs.vimPlugins.nvim-treesitter.withPlugins (treesitter-plugins:
        with treesitter-plugins; [
          bash
          c
          lua
          markdown
          markdown_inline
          nix
          python
          vim
          vimdoc
        ]);
      in
    with pkgs.vimPlugins; [
      todo-comments-nvim
      edge
      nvim-cmp
      nvim-treesitter-with-plugins
      vim-autoformat
      vim-nix
    ];
    extraLuaConfig = builtins.readFile ./init.lua;
  };
}
