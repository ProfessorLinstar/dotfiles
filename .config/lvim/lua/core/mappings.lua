--------------------------------------------------------------------------------
-- Lunarvim mappings (should go after 'leader' definition)
--------------------------------------------------------------------------------

vim.api.nvim_set_keymap("n", "<Leader>j", "<cmd>BufferLinePick<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Leader>;", '<cmd>if luaeval("vim.bo.ft") != "alpha" | tab split | endif | execute "Alpha" | cd %:p:h<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Leader>t", '<cmd>Telescope live_grep<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Leader>f", '<cmd>Telescope find_files<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-t>", '<cmd>ToggleTerm<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap("", "H", "H", { noremap = true })
vim.api.nvim_set_keymap("", "L", "L", { noremap = true })
vim.api.nvim_set_keymap("", "L", "L", { noremap = true })

-- Prevent nvimtree from stealing tab key
local function nvim_tree_on_attach(bufnr)
  local api = require "nvim-tree.api"

  local function telescope_find_files(_)
    require("lvim.core.nvimtree").start_telescope "find_files"
  end

  local function telescope_live_grep(_)
    require("lvim.core.nvimtree").start_telescope "live_grep"
  end

  local function opts(desc)
    return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
  end

  api.config.mappings.default_on_attach(bufnr)

  local useful_keys = {
    ["l"] = { api.node.open.edit, opts "Open" },
    ["o"] = { api.node.open.edit, opts "Open" },
    ["<CR>"] = { api.node.open.edit, opts "Open" },
    ["v"] = { api.node.open.vertical, opts "Open: Vertical Split" },
    ["h"] = { api.node.navigate.parent_close, opts "Close Directory" },
    ["C"] = { api.tree.change_root_to_node, opts "CD" },
    ["gtg"] = { telescope_live_grep, opts "Telescope Live Grep" },
    ["gtf"] = { telescope_find_files, opts "Telescope Find File" },
    ["<tab>"] = { "<C-w>w", opts "Next Tab"}
  }

  require("lvim.keymappings").load_mode("n", useful_keys)
end
lvim.builtin.nvimtree.setup.on_attach = nvim_tree_on_attach

--------------------------------------------------------------------------------
-- which-key modifications
--------------------------------------------------------------------------------

-- which_key overridings
lvim.builtin.which_key.mappings["b"]["l"] = { nil, "List Buffers (:buffers)" }
lvim.builtin.which_key.mappings["b"]["h"] = nil
lvim.builtin.which_key.mappings["s"]["t"] = nil
lvim.builtin.which_key.mappings["s"]["f"] = nil

-- Key overridings
lvim.keys.insert_mode["jk"] = false
lvim.keys.insert_mode["jj"] = false
lvim.keys.insert_mode["kj"] = false

-- Menu labels
lvim.builtin.which_key.mappings["d"] = { name = "Protected Menu" }
lvim.builtin.which_key.mappings["a"] = { name = "Shortcuts" }

-- Dictionary for nameless mappings
lvim.builtin.which_key.mappings["y"] = {
  name = "Dictionary",
  j = { nil, "Jump to buffer (:BufferLinePick)" },
  r = { nil, "Disable highlighting (:noh)" },
  w = { nil, "Write (:w)" },
  t = { nil, "Search Text (:Telescope live_grep)" },
  c = { nil, "cd to current file (:cd %:p:h)" },
  C = { nil, "cd to current Session.vim (v:this_session)" },
  q = { nil, "Quit All (:qa)" },
  Q = { nil, "Toggle syntax (M-q)" },
  v = { nil, "Tab Split (:tab split)" },
  x = { nil, "Delete Tab (:tabclose)" },
}

-- Hide basic mappings from which-key menu
local ignore = { "j", "r", "w", "t", "c", "C", "q", "v", "x", "'", "/", "z", "Z", "h", ";", "f"}
for _, letter in pairs(ignore) do lvim.builtin.which_key.mappings[letter] = { nil, "which_key_ignore" } end
