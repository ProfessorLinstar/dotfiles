--------------------------------------------------------------------------------
-- Lunarvim mappings (should go after 'leader' definition)
--------------------------------------------------------------------------------

vim.api.nvim_set_keymap("n", "<Leader>j", "<cmd>BufferLinePick<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Leader>;", '<cmd>if luaeval("vim.bo.ft") != "alpha" | tab split | endif | execute "Alpha" | cd %:p:h<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap("", "H", "H", { noremap = true })
vim.api.nvim_set_keymap("", "L", "L", { noremap = true })

-- Prevent nvimtree from stealing tab key
table.insert(lvim.builtin.nvimtree.setup.view.mappings.list, { key = "<Tab>", action = "" })
table.insert(lvim.builtin.nvimtree.setup.view.mappings.list, { key = "f", action = "" }) -- prevent nvimtree from breaking vim-sneak

--------------------------------------------------------------------------------
-- which-key modifications
--------------------------------------------------------------------------------

-- Builtin overriding
lvim.builtin.which_key.mappings["b"]["l"] = { nil, "List Buffers (:buffers)" }
lvim.builtin.which_key.mappings["b"]["h"] = nil

-- Menu labels
lvim.builtin.which_key.mappings["d"] = { name = "Protected Menu" }
lvim.builtin.which_key.mappings["a"] = { name = "Shortcuts" }

-- Dictionary for nameless mappings
lvim.builtin.which_key.mappings["y"] = {
  name = "Dictionary",
  j = { nil, "Jump to buffer (:BufferLinePick)" },
  r = { nil, "Disable highlighting (:noh)" },
  w = { nil, "Write (:w)" },
  t = { nil, "Goto clipboard line number" },
  c = { nil, "cd to current file (:cd %:p:h)" },
  C = { nil, "cd to current Session.vim (v:this_session)" },
  q = { nil, "Quit All (:qa)" },
  Q = { nil, "Toggle syntax (M-q)" },
  v = { nil, "Tab Split (:tab split)" },
  x = { nil, "Delete Tab (:tabclose)" },
  ["'"] = { "<Plug>Sneak_S", "Sneak backwards (:<Plug>Sneak_S)" },
}

-- Hide basic mappings from which-key menu
local ignore = { "r", "w", "t", "c", "C", "q", "v", "x", "'", "/", "z", "Z", "h", ";", "j" }
for _, letter in pairs(ignore) do lvim.builtin.which_key.mappings[letter] = { nil, "which_key_ignore" } end
