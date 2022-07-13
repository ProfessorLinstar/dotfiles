-- Builtin modifications
local merge = {
  l = { nil, "List Buffers (:buffers)" },
  h = nil
}
for k, v in pairs(merge) do lvim.builtin.which_key.mappings["b"][k] = v end

-- Prevent nvimtree from stealing tab key
table.insert(lvim.builtin.nvimtree.setup.view.mappings.list, { key = "<Tab>", action = "" })

-- Label menus
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
  [";"] = { nil, "Alpha" },
}


-- Hide basic mappings from which-key menu
local ignore = { "j", "r", "w", "t", "c", "C", "q", "v", "x", ";", "'", "/", "z", "Z", "h" }
for _, letter in pairs(ignore) do lvim.builtin.which_key.mappings[letter] = { nil, "which_key_ignore" } end
