return {
  "krady21/compiler-explorer.nvim",
  dependencies = { "stevearc/dressing.nvim" },
  cmd = {
    "CECompile",
    "CECompileLive",
    "CEFormat",
    "CEAddLibrary",
    "CELoadExample",
    "CEOpenWebsite",
    "CEDeleteCache",
    "CEShowTooltip",
    "CEGotoLabel",
  },
  config = function()
    require("compiler-explorer").setup {
      url = "https://godbolt.org",
      infer_lang = true,
      binary = false,
      comment_only = true,
      directives = true,
      labels = true,
      intel = true,
      demangle = true,
      highlights = {
        cursor = "Visual",
        static = "Normal",
      },
      autoclean = true,
      diagnostic_surpress = false,
      split = "split",
      spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
    }
  end,
}
