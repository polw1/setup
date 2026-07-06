return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("gitsigns").setup {
      signs = {
        add = { text = "│" },
        change = { text = "│" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        vim.keymap.set("n", "]c", function()
          if vim.wo.diff then return "]c" end
          vim.schedule(function() gs.next_hunk() end)
          return "<Ignore>"
        end, { buffer = bufnr, expr = true, desc = "Próximo hunk" })

        vim.keymap.set("n", "[c", function()
          if vim.wo.diff then return "[c" end
          vim.schedule(function() gs.prev_hunk() end)
          return "<Ignore>"
        end, { buffer = bufnr, expr = true, desc = "Hunk anterior" })

        vim.keymap.set("n", "<leader>ph", gs.preview_hunk, { buffer = bufnr, desc = "Preview do hunk" })
        vim.keymap.set("n", "<leader>rh", gs.reset_hunk, { buffer = bufnr, desc = "Resetar hunk" })
        vim.keymap.set("n", "<leader>gb", gs.blame_line, { buffer = bufnr, desc = "Blame da linha" })
      end,
    }
  end,
}
