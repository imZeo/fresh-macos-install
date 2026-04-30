return {
  "folke/tokyonight.nvim",
  lazy = false,  -- Load immediately
  priority = 1000,  -- Ensure it's loaded before other plugins
  config = function()
    vim.cmd("colorscheme tokyonight-storm")
  end,
}

