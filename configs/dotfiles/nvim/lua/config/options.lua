local opt = vim.opt
local g = vim.g

-- leader
vim.g.mapleader = " "

-- aparência
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.colorcolumn = "100"
opt.termguicolors = true
opt.laststatus = 3
opt.showmode = false
opt.fillchars = { eob = " " }
opt.shortmess:append "sI"

-- indentação
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

-- busca
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true

-- comportamento
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.undofile = true
opt.swapfile = false
opt.updatetime = 250
opt.timeoutlen = 400
opt.splitbelow = true
opt.splitright = true
opt.wrap = false

-- navegação entre linhas longas
opt.whichwrap:append "<>[]hl"

-- desabilita providers que não vamos usar
for _, provider in ipairs { "node", "perl", "python3", "ruby" } do
  g["loaded_" .. provider .. "_provider"] = 0
end
