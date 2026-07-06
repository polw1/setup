return {
  "nvim-telescope/telescope.nvim",
  tag = "0.1.8",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope-file-browser.nvim",
  },
  cmd = "Telescope",
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Buscar arquivos" },
    { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Buscar texto" },
    { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buscar buffers" },
    { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Buscar ajuda" },
    { "<leader>fo", "<cmd>Telescope oldfiles<CR>", desc = "Arquivos recentes" },
    { "<leader>fc", "<cmd>Telescope git_commits<CR>", desc = "Commits do git" },
    { "<leader>gs", "<cmd>Telescope git_status<CR>", desc = "Status do git" },
  },
  config = function()
    local actions = require "telescope.actions"
    local action_state = require "telescope.actions.state"
    local fb_actions = require("telescope").extensions.file_browser.actions

    local function get_selected_dir()
      local selection = action_state.get_selected_entry()
      if not selection then
        return nil
      end
      local path = selection.path or selection.filename or selection.value
      if not path then
        return nil
      end
      path = vim.fn.fnamemodify(path, ":p")
      return vim.fn.fnamemodify(path, ":h")
    end

    local function open_oil_from_telescope(prompt_bufnr)
      local dir = get_selected_dir()
      if not dir then
        return
      end
      actions.close(prompt_bufnr)
      require("oil").open(dir)
    end

    local function open_terminal_from_telescope(prompt_bufnr)
      local dir = get_selected_dir()
      if not dir then
        return
      end
      actions.close(prompt_bufnr)

      vim.cmd "split"
      local win = vim.api.nvim_get_current_win()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(win, buf)
      vim.fn.termopen(vim.o.shell, { cwd = dir })
      vim.cmd "startinsert"
    end

    local custom_mappings = {
      i = {
        ["<C-o>"] = open_oil_from_telescope,
        ["<A-o>"] = open_terminal_from_telescope,
      },
      n = {
        ["<C-o>"] = open_oil_from_telescope,
        ["<A-o>"] = open_terminal_from_telescope,
      },
    }

    require("telescope").setup {
      defaults = {
        prompt_prefix = "  ",
        selection_caret = "  ",
        path_display = { "smart" },
        initial_mode = "normal",
        mappings = custom_mappings,
      },
      extensions = {
        file_browser = {
          mappings = custom_mappings,
        },
      },
    }

    require("telescope").load_extension "file_browser"
  end,
}
