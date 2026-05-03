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

local function optional_require(module)
  local ok, loaded = pcall(require, module)
  if ok then
    return loaded
  end

  vim.notify("Neovim plugin not found: " .. module, vim.log.levels.WARN)
  return nil
end

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

local ok, treesitter = pcall(require, "nvim-treesitter.configs")
if ok then
  local status, _ = pcall(function()
    treesitter.setup {
      auto_install = false,
      highlight = {
        enable = true,
      },
      indent = {
        enable = true,
      },
    }
  end)
  if not status then
    vim.notify("Treesitter setup failed", vim.log.levels.WARN)
  end
else
  -- Treesitter not available, but that's okay
end

-----------------------------------------------------------
-- TODO Comments Highlighting
-----------------------------------------------------------

local todo_comments = optional_require("todo-comments")
if todo_comments then
  todo_comments.setup {}
end

-----------------------------------------------------------
-- Indent Guides (indent-blankline-nvim)
-----------------------------------------------------------

local ibl = optional_require("ibl")
if ibl then
  ibl.setup({
    indent = {
      char = {"|"}
    }
  })
end

-----------------------------------------------------------
-- Autocompletion (nvim-cmp)
-----------------------------------------------------------

local cmp = optional_require("cmp")

if cmp then
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
end
