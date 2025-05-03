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
        csv-vim
        edge
        indent-blankline-nvim
        jedi-vim
        nvim-cmp
        nvim-treesitter-with-plugins
        todo-comments-nvim
        vim-airline
        vim-airline-themes
        vim-nix
        vim-autoformat
      ];
    extraLuaConfig = builtins.readFile ./init.lua;
  };
}
