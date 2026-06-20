return {
  "folke/tokyonight.nvim",
  opts = {
    transparent = true,
    styles = {
      sidebars = "transparent",
      floats = "transparent",
    },
    on_highlights = function(hl, c)
      hl.Normal = { bg = "none" }
      hl.NormalNC = { bg = "none" }
      hl.EndOfBuffer = { bg = "none" }
      hl.CursorLine = { bg = "none", underline = true }
    end,
  },
}
