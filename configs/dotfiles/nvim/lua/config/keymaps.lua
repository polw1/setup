local keymap = vim.keymap

-- limpar highlights
keymap.set("n", "<Esc>", "<cmd>noh<CR>", { desc = "Limpar highlights" })

-- salvar e sair
keymap.set("n", "<C-s>", "<cmd>w<CR>", { desc = "Salvar arquivo" })
keymap.set("n", "<leader>q", "<cmd>q<CR>", { desc = "Sair" })

-- navegação entre janelas com Ctrl + h/j/k/l
keymap.set("n", "<C-h>", "<C-w>h", { desc = "Janela esquerda" })
keymap.set("n", "<C-j>", "<C-w>j", { desc = "Janela abaixo" })
keymap.set("n", "<C-k>", "<C-w>k", { desc = "Janela acima" })
keymap.set("n", "<C-l>", "<C-w>l", { desc = "Janela direita" })

-- redimensionar janelas
keymap.set("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Aumentar altura" })
keymap.set("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Diminuir altura" })
keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Diminuir largura" })
keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Aumentar largura" })

-- buffers
keymap.set("n", "<Tab>", "<cmd>bnext<CR>", { desc = "Próximo buffer" })
keymap.set("n", "<S-Tab>", "<cmd>bprevious<CR>", { desc = "Buffer anterior" })
keymap.set("n", "<leader>x", "<cmd>bdelete<CR>", { desc = "Fechar buffer" })
keymap.set("n", "<leader>b", "<cmd>enew<CR>", { desc = "Novo buffer" })

-- mover linhas
keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Mover seleção para baixo" })
keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Mover seleção para cima" })

-- indentar sem perder seleção
keymap.set("v", "<", "<gv", { desc = "Indentar esquerda" })
keymap.set("v", ">", ">gv", { desc = "Indentar direita" })

-- não substituir o registrador ao colar no modo visual
keymap.set("x", "p", 'p:let @+=@0<CR>:let @"=@0<CR>', { desc = "Colar sem substituir yank" })

-- copiar arquivo inteiro
keymap.set("n", "<C-c>", "<cmd>%y+<CR>", { desc = "Copiar arquivo inteiro" })

-- LSP
keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Ir para definição" })
keymap.set("n", "gr", vim.lsp.buf.references, { desc = "Referências" })
keymap.set("n", "gI", vim.lsp.buf.implementation, { desc = "Implementação" })
keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover" })
keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Ação de código" })
keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Renomear" })
keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Diagnóstico anterior" })
keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Próximo diagnóstico" })
keymap.set("n", "<leader>f", function()
  vim.lsp.buf.format { async = true }
end, { desc = "Formatar com LSP" })

-- Oil
keymap.set("n", "-", "<cmd>Oil<CR>", { desc = "Abrir diretório pai" })

-- Neogit
keymap.set("n", "<leader>gg", "<cmd>Neogit<CR>", { desc = "Abrir Neogit" })

-- comando :Ff (acessível também como :ff) para abrir Telescope find_files
vim.api.nvim_create_user_command("Ff", function()
  vim.cmd "Telescope find_files"
end, { desc = "Buscar arquivos com Telescope" })

vim.cmd "cnoreabbrev ff Ff"

-- comando :Fd (acessível também como :fd) para buscar pastas recursivamente
vim.api.nvim_create_user_command("Fd", function()
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"

  require("telescope.builtin").find_files {
    prompt_title = "Buscar pastas",
    find_command = { "fd", "--type", "directory", "--hidden", "--exclude", ".git" },
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          require("oil").open(selection.path or selection.value)
        end
      end)
      return true
    end,
  }
end, { desc = "Buscar pastas recursivamente com Telescope" })

vim.cmd "cnoreabbrev fd Fd"

-- comando :Fdd (acessível também como :fdd) para navegar só por diretórios
vim.api.nvim_create_user_command("Fdd", function()
  vim.cmd "Telescope file_browser"
end, { desc = "Navegar diretórios com Telescope" })

vim.cmd "cnoreabbrev fdd Fdd"

-- comando :Fdev (acessível também como :fdev) para abrir file_browser em ~/dev
vim.api.nvim_create_user_command("Fdev", function()
  vim.cmd "Telescope file_browser path=/home/pdc/dev"
end, { desc = "Abrir file_browser em ~/dev" })

vim.cmd "cnoreabbrev fdev Fdev"

-- comando :Fb (acessível também como :fb) para abrir Telescope buffers
vim.api.nvim_create_user_command("Fb", function()
  vim.cmd "Telescope buffers"
end, { desc = "Buscar buffers com Telescope" })

vim.cmd "cnoreabbrev fb Fb"

-- comando :Setcwd para definir o cwd como a pasta atual do oil
vim.api.nvim_create_user_command("Setcwd", function()
  if vim.bo.filetype == "oil" then
    local dir = require("oil").get_current_dir()
    if dir then
      vim.api.nvim_set_current_dir(dir)
      print("Cwd alterado para: " .. dir)
    end
  else
    local dir = vim.fn.expand "%:p:h"
    vim.api.nvim_set_current_dir(dir)
    print("Cwd alterado para: " .. dir)
  end
end, { desc = "Definir cwd como diretório atual" })

vim.cmd "cnoreabbrev setcwd Setcwd"

-- comando :T para abrir terminal no diretório atual (oil, arquivo, ou cwd)
vim.api.nvim_create_user_command("T", function()
  local cwd
  if vim.bo.filetype == "oil" then
    cwd = require("oil").get_current_dir()
  elseif vim.fn.expand("%:p") ~= "" then
    cwd = vim.fn.expand("%:p:h")
  else
    cwd = vim.fn.getcwd()
  end

  vim.cmd "split"
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.fn.termopen(vim.o.shell, { cwd = cwd })
  vim.cmd "startinsert"
end, { desc = "Abrir terminal no diretório atual" })

-- comando :Fg (acessível também como :fg) para abrir Telescope live_grep
vim.api.nvim_create_user_command("Fg", function()
  vim.cmd "Telescope live_grep"
end, { desc = "Buscar texto no projeto com Telescope" })

vim.cmd "cnoreabbrev fg Fg"

-- deletar todos os buffers menos o atual
vim.api.nvim_create_user_command("Bonly", function()
  local current = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= current and vim.bo[buf].buflisted then
      vim.cmd("bdelete " .. buf)
    end
  end
end, { desc = "Deletar todos os buffers menos o atual" })

vim.api.nvim_create_user_command("BonlyF", function()
  local current = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= current and vim.bo[buf].buflisted then
      vim.cmd("bdelete! " .. buf)
    end
  end
end, { desc = "Deletar todos os buffers menos o atual (forçado)" })

keymap.set("n", "<leader>bo", "<cmd>Bonly<CR>", { desc = "Manter só o buffer atual" })
keymap.set("n", "<leader>bO", "<cmd>BonlyF<CR>", { desc = "Manter só o buffer atual (forçado)" })
