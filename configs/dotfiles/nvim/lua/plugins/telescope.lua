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

    local function force_delete_buffer(prompt_bufnr)
      local current_picker = action_state.get_current_picker(prompt_bufnr)
      current_picker:delete_selection(function(selection)
        local ok = pcall(vim.api.nvim_buf_delete, selection.bufnr, { force = true })
        return ok
      end)
    end

    local function rename_buffer(prompt_bufnr)
      local selection = action_state.get_selected_entry()
      if not selection or not selection.bufnr then
        return
      end

      local bufnr = selection.bufnr
      local old_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
      if old_name == "" then
        old_name = "sem nome"
      end

      actions.close(prompt_bufnr)

      vim.ui.input({
        prompt = "Novo nome do buffer: ",
        default = old_name,
      }, function(new_name)
        if not new_name or new_name == "" or new_name == old_name then
          return
        end

        vim.api.nvim_buf_set_name(bufnr, new_name)
        vim.notify("Buffer renomeado para " .. new_name, vim.log.levels.INFO)
      end)
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
      pickers = {
        buffers = {
          sort_lastused = true,
          sort_mru = true,
          attach_mappings = function(prompt_bufnr, map)
            map("i", "<C-d>", actions.delete_buffer)
            map("n", "<C-d>", actions.delete_buffer)
            map("i", "<C-D>", force_delete_buffer)
            map("n", "<C-D>", force_delete_buffer)
            map("i", "<C-r>", rename_buffer)
            map("n", "<C-r>", rename_buffer)
            map("n", "r", rename_buffer)
            return true
          end,
        },
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
