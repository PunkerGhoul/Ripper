{ pkgs, unstable, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    withPython3 = true;
    withRuby = true;
    plugins = let
      nvim-treesitter-with-plugins =
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
    ]);
    initLua = builtins.readFile ./init.lua;
  };
}
