-----------------------------------------------------------
-- Core Options
-----------------------------------------------------------

-- Show line numbers
vim.opt.number = true

-- Enable mouse support
vim.opt.mouse = "a"

-- Use true colors in terminal
vim.opt.termguicolors = true

-- Highlight the current line
vim.opt.cursorline = true

-- Show invisible characters like tabs and trailing spaces
vim.opt.list = true

-----------------------------------------------------------
-- Indentation
-----------------------------------------------------------

-- Number of visual spaces per tab
vim.opt.tabstop = 2

-- Number of spaces inserted with tab key
vim.opt.softtabstop = 2

-- Number of spaces for each indentation level
vim.opt.shiftwidth = 2

-- Use spaces instead of tabs
vim.opt.expandtab = true

-----------------------------------------------------------
-- Appearance
-----------------------------------------------------------

-- Set the colorscheme (requires the 'edge' theme plugin)
vim.cmd("colorscheme edge")

-- Highlight search results
vim.opt.hlsearch = true
vim.api.nvim_set_hl(0, "Search", {
  fg = "#00ff00",    -- green
  bg = "#ffff99",    -- light yellow
  bold = true,
})

-----------------------------------------------------------
-- Filetypes and Syntax
-----------------------------------------------------------

-- Enable filetype detection and indenting
vim.cmd("filetype plugin indent on")

-- Enable syntax highlighting
vim.cmd("syntax on")

-----------------------------------------------------------
-- Treesitter Configuration
-----------------------------------------------------------

require("nvim-treesitter.configs").setup {
  highlight = {
    enable = true,
  },
  indent = {
    enable = true,
  },
}

-----------------------------------------------------------
-- TODO Comments Highlighting
-----------------------------------------------------------

require("todo-comments").setup {}

-----------------------------------------------------------
-- Indent Guides (indent-blankline-nvim)
-----------------------------------------------------------

require("ibl").setup({
  indent = {
    char = {"|"}
  }
})

-----------------------------------------------------------
-- Autocompletion (nvim-cmp)
-----------------------------------------------------------

local cmp = require("cmp")

cmp.setup({
  mapping = {
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
  },
  sources = {
    { name = "nvim_lsp" },
    { name = "buffer" },
  },
})

