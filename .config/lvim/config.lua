--------------------------------------------------------------------------------
-- Program: ~/.config/lvim/config.lua
-- Description: Lunarvim configuration file.
-- Modified Files: None.
--------------------------------------------------------------------------------

local lua_sources = {
  "core/mappings", -- "~/dotfiles/.config/lvim/lua/core/mappings.lua" Lunarvim mappings
  "core/options",  -- "~/dotfiles/.config/lvim/lua/core/options.lua"  Lunarvim options
}
for _, file in pairs(lua_sources) do require(file) end


local vim_sources = {
  "~/dotfiles/.config/nvim/core/commands.vim",     -- Basic vim commands
  "~/dotfiles/.config/nvim/core/autocommands.vim", -- Basic vim autocommands
  "~/dotfiles/.config/nvim/core/options.vim",      -- Basic vim options
  "~/dotfiles/.config/nvim/core/mappings.vim",     -- Basic vim mappings
  "~/dotfiles/.config/nvim/core/plugmaps.vim",     -- Plugin mappings
}
for _, file in pairs(vim_sources) do vim.cmd("source " .. file) end
