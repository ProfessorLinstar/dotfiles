--------------------------------------------------------------------------------
-- General settings
--------------------------------------------------------------------------------

lvim.log.level = "warn"
lvim.format_on_save = true
lvim.colorscheme = "onedarker"

--------------------------------------------------------------------------------
-- Builtin Settings
--------------------------------------------------------------------------------

lvim.builtin.lualine.sections.lualine_z = { "location" } -- show line/column number in ruler
lvim.builtin.cmp.preselect = false -- don't select suggestion automatically

-- After changing plugin config exit and reopen LunarVim, Run :PackerInstall :PackerCompile
lvim.builtin.alpha.active = true
lvim.builtin.notify.active = true
lvim.builtin.terminal.active = true
lvim.builtin.nvimtree.setup.view.side = "left"

lvim.format_on_save = false -- prevent automatic formatting on write
lvim.builtin.treesitter.ensure_installed = { "bash", "json", "python", "lua", "latex", "vim" }
lvim.builtin.treesitter.ignore_install = { "haskell" }
lvim.builtin.treesitter.indent = { enable = true, disable = { "python", "go", "tex" } } -- prevent treesitter from breaking indenting
lvim.builtin.treesitter.highlight.enabled = true

-- LSP Setup
local pid = vim.fn.getpid()
local omnisharp_bin = "/home/linstar/.local/share/nvim/lsp_servers/omnisharp/omnisharp/OmniSharp"
require('lspconfig').omnisharp.setup { cmd = {omnisharp_bin, "--languageserver", "--hostPID", tostring(pid)} }

--------------------------------------------------------------------------------
-- Plugins
--------------------------------------------------------------------------------

lvim.plugins = {
  { "folke/tokyonight.nvim" },   -- Default LunarVim theme
  { "tpope/vim-obsession" },     -- Improve vim sessions functionality for tmux
  { "tpope/vim-surround" },      -- Provides some keybindings for delimiter manipulation
  { "justinmk/vim-sneak" },      -- Faster navigation keybindings
  { "moll/vim-bbye" },           -- More intelligent buffer deletion
  { "tpope/vim-fugitive" },      -- Git-integration for vim
  { "lervag/vimtex" },           -- Provides LaTeX bindings and compilation features
  {
    "ray-x/lsp_signature.nvim",  -- LSP signature help
    config = function() require "lsp_signature".on_attach() end,
    event = "BufRead",
  },
}

vim.g.vimtex_view_general_viewer = 'okular'
vim.g.vimtex_view_general_options = '--unique file:@pdf#src:@line@tex'
vim.g.vimtex_indent_on_ampersands = 0
-- Okular inverse search command: sh -c "echo -n \"%l\" | xclip -selection clipboard"
