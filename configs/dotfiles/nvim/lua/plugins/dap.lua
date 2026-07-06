return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "theHamsta/nvim-dap-virtual-text",
    "jay-babu/mason-nvim-dap.nvim",
    "mfussenegger/nvim-dap-python",
    "nvim-neotest/nvim-nio",
  },
  config = function()
    local dap = require "dap"
    local dapui = require "dapui"
    local keymap = vim.keymap

    dapui.setup()
    require("nvim-dap-virtual-text").setup {
      commented = true,
    }

    require("mason-nvim-dap").setup {
      ensure_installed = { "python", "codelldb", "js-debug-adapter" },
      automatic_installation = true,
      handlers = {},
    }

    -- configuração Python
    require("dap-python").setup "python"

    -- configuração C/C++/Rust com codelldb
    dap.adapters.codelldb = {
      type = "server",
      port = "${port}",
      executable = {
        command = vim.fn.stdpath "data" .. "/mason/bin/codelldb",
        args = { "--port", "${port}" },
      },
    }

    local c_cpp_rust_config = {
      {
        name = "Launch file",
        type = "codelldb",
        request = "launch",
        program = function()
          return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
      },
    }

    dap.configurations.c = c_cpp_rust_config
    dap.configurations.cpp = c_cpp_rust_config
    dap.configurations.rust = c_cpp_rust_config

    -- configuração JavaScript/TypeScript com js-debug-adapter
    dap.configurations.javascript = {
      {
        name = "Launch file",
        type = "js-debug-adapter",
        request = "launch",
        program = "${file}",
        cwd = "${workspaceFolder}",
        sourceMaps = true,
      },
      {
        name = "Attach to process",
        type = "js-debug-adapter",
        request = "attach",
        processId = require("dap.utils").pick_process,
        cwd = "${workspaceFolder}",
        sourceMaps = true,
      },
    }

    dap.configurations.typescript = dap.configurations.javascript
    dap.configurations.javascriptreact = dap.configurations.javascript
    dap.configurations.typescriptreact = dap.configurations.javascript

    -- abre e fecha a UI automaticamente
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end

    -- atalhos
    keymap.set("n", "<F5>", dap.continue, { desc = "DAP: continuar" })
    keymap.set("n", "<F10>", dap.step_over, { desc = "DAP: step over" })
    keymap.set("n", "<F11>", dap.step_into, { desc = "DAP: step into" })
    keymap.set("n", "<F12>", dap.step_out, { desc = "DAP: step out" })
    keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = "DAP: breakpoint" })
    keymap.set("n", "<leader>du", dapui.toggle, { desc = "DAP: toggle UI" })
    keymap.set("n", "<leader>dr", dap.repl.open, { desc = "DAP: REPL" })
    keymap.set("n", "<leader>dl", dap.run_last, { desc = "DAP: última sessão" })
  end,
}
