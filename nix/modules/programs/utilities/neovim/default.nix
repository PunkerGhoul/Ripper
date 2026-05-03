{ pkgs, unstable, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    withPython3 = true;
    withRuby = true;
    extraPackages = [
      pkgs.tree-sitter
    ];
    plugins = let
      nvimTreesitter =
        pkgs.vimPlugins.nvim-treesitter.withPlugins (treesitter-plugins:
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
      [
        unstable.vimPlugins.copilot-vim
      ] ++ (with pkgs.vimPlugins; [
      csv-vim
      cmp-buffer
      cmp-nvim-lsp
      edge
      indent-blankline-nvim
      jedi-vim
      nvim-cmp
      nvim-treesitter-textobjects
      nvimTreesitter
      plenary-nvim
      todo-comments-nvim
      vim-airline
      vim-airline-themes
      vim-nix
      vim-autoformat
    ]);
    initLua = builtins.readFile ./init.lua;
  };
}
