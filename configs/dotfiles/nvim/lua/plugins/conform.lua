return {
  "stevearc/conform.nvim",
  event = { "BufReadPost", "BufNewFile" },
  cmd = "ConformInfo",
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format { async = true, lsp_fallback = true }
      end,
      desc = "Formatar arquivo",
    },
  },
  config = function()
    require("conform").setup {
      formatters_by_ft = {
        lua = { "stylua" },
        rust = { "rustfmt" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        python = { "black" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        html = { "prettier" },
        css = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        sql = { "sql_formatter" },
      },
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = true,
      },
    }
  end,
}
