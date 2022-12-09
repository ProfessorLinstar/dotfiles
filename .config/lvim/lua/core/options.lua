--------------------------------------------------------------------------------
-- Lunarvim settings
--------------------------------------------------------------------------------

-- vim builtin
vim.opt.showmode = true

-- lvim builtin
lvim.log.level = "warn"
lvim.format_on_save = false
lvim.colorscheme = "onedark"

lvim.builtin.lualine.sections.lualine_z = { "location" } -- show line/column number in ruler
lvim.builtin.cmp.preselect = false -- don't select suggestion automatically

lvim.builtin.alpha.active = true
lvim.builtin.terminal.active = true
lvim.builtin.nvimtree.setup.view.side = "left"

lvim.builtin.treesitter.ensure_installed = { "bash", "json", "python", "lua" }
lvim.builtin.treesitter.ignore_install = { "haskell", "latex" }
lvim.builtin.treesitter.highlight.enabled = true
lvim.builtin.treesitter.indent = { enable = true, disable = { "python", "go", "tex" } } -- prevent treesitter from breaking indenting

-- LSP Settings
local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup {
  { name = "yapf" },
  { name = "prettier", filetypes = { "vue" } },
  { name = "goimports"}
}

local linters = require "lvim.lsp.null-ls.linters"
linters.setup {}

--------------------------------------------------------------------------------
-- External Plugins
--------------------------------------------------------------------------------

-- After changing plugin config exit and reopen LunarVim, Run :PackerInstall :PackerCompile
lvim.plugins = {
  { "tpope/vim-obsession" },        -- Improve vim sessions functionality for tmux
  { "tpope/vim-surround" },         -- Provides some keybindings for delimiter manipulation
  { "ggandor/leap.nvim" },          -- Faster navigation keybindings
  { "moll/vim-bbye" },              -- More intelligent buffer deletion
  { "tpope/vim-fugitive" },         -- Git-integration for vim
  { "ray-x/lsp_signature.nvim" },   -- LSP signature help
  { "navarasu/onedark.nvim" },      -- More colorful onedark theme

  -- filetype specific plugins
  { "lervag/vimtex", },             -- Provides LaTeX bindings and compilation features
  {
    "iamcco/markdown-preview.nvim", -- Markdown preview
    run = "cd app && npm install",
    ft = "markdown"
  },

}

-- Extra setup
require "leap".opts.safe_labels = {}
require "lsp_signature".setup { toggle_key = "<C-s>", select_signature_key = "<M-s>" }
require "onedark".setup {
  style = "warmer",
  code_style = { keywords = "bold", functions = "italic,bold" },
  colors = {
    bg0 = "#1c1c1c",
    bg_d = "#232326",
  }
}

-- vimtex
vim.g.vimtex_view_general_viewer = 'okular'
vim.g.vimtex_view_general_options = 'file:@pdf#src:@line@tex'
vim.g.vimtex_indent_on_ampersands = 0
-- Okular inverse search command: sh -c "echo -n \"%l\" | xclip -selection clipboard"

-- markdown-preview.nvim
vim.g.mkdp_theme = 'dark'
vim.g.mkdp_auto_close = 0
