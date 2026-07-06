return {
  "numToStr/Comment.nvim",
  keys = {
    { "gcc", mode = "n", desc = "Comentar linha" },
    { "gc", mode = { "n", "o", "x" }, desc = "Comentar" },
    { "gbc", mode = "n", desc = "Comentar bloco" },
    { "gb", mode = { "n", "o", "x" }, desc = "Comentar bloco" },
  },
  config = function()
    require("Comment").setup()
  end,
}
