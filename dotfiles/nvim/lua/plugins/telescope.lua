return {
    'nvim-telescope/telescope.nvim',

    tag = '0.1.8',
	dependencies = {
	      'nvim-lua/plenary.nvim'
      },
  config = function()
    require("telescope").setup({
      defaults = {
        layout_config = {
          prompt_position = "top",
        },
        sorting_strategy = "ascending",
        mappings = {
          i = {
            ["<C-k>"] = require("telescope.actions").move_selection_previous, -- Move up
            ["<C-j>"] = require("telescope.actions").move_selection_next, -- Move down
          },
        },
      },
      pickers = {
        find_files = {
          theme = "dropdown",
        },
      },
    })
  end

    }

