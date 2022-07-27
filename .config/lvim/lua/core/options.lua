--------------------------------------------------------------------------------
-- Lunarvim settings
--------------------------------------------------------------------------------

vim.opt.showmode = true
lvim.log.level = "warn"
lvim.format_on_save = false
lvim.colorscheme = "onedark"

lvim.builtin.lualine.sections.lualine_z = { "location" } -- show line/column number in ruler
lvim.builtin.cmp.preselect = false -- don't select suggestion automatically

lvim.builtin.alpha.active = true
lvim.builtin.notify.active = true
lvim.builtin.terminal.active = true
lvim.builtin.nvimtree.setup.view.side = "left"

lvim.builtin.treesitter.ensure_installed = { "bash", "json", "python", "lua" }
lvim.builtin.treesitter.ignore_install = { "haskell", "latex" }
lvim.builtin.treesitter.highlight.enabled = true
lvim.builtin.treesitter.indent = { enable = true, disable = { "python", "go", "tex" } } -- prevent treesitter from breaking indenting

lvim.lsp.automatic_servers_installation = false

local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup {
  { name = "yapf", args = {"--style={based_on_style: google, column_limit: 120}"} }
}

local linters = require "lvim.lsp.null-ls.linters"
linters.setup {
  { name = "pylint", args = {"--disable=C0321,W0603"} },
}

--------------------------------------------------------------------------------
-- External Plugins
--------------------------------------------------------------------------------

-- After changing plugin config exit and reopen LunarVim, Run :PackerInstall :PackerCompile
lvim.plugins = {
  { "folke/tokyonight.nvim" },      -- Default LunarVim theme
  { "tpope/vim-obsession" },        -- Improve vim sessions functionality for tmux
  { "tpope/vim-surround" },         -- Provides some keybindings for delimiter manipulation
  { "justinmk/vim-sneak" },         -- Faster navigation keybindings
  { "moll/vim-bbye" },              -- More intelligent buffer deletion
  { "tpope/vim-fugitive" },         -- Git-integration for vim
  { "lervag/vimtex" },              -- Provides LaTeX bindings and compilation features
  { "ray-x/lsp_signature.nvim" },   -- LSP signature help
  { "olimorris/onedarkpro.nvim" },  -- LSP signature help
  { "navarasu/onedark.nvim" },      -- LSP signature help
}

require "lsp_signature".setup { toggle_key = "<C-s>", select_signature_key = "<M-s>" }
require "onedark".setup { style = "warmer", toggle_style_key = "<C-M-S-F12>", code_style = { keywords = "bold", functions = "italic,bold" } }

vim.g.vimtex_view_general_viewer = 'okular'
vim.g.vimtex_view_general_options = '--unique file:@pdf#src:@line@tex'
vim.g.vimtex_indent_on_ampersands = 0
-- Okular inverse search command: sh -c "echo -n \"%l\" | xclip -selection clipboard"
