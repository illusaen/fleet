return {
  -- 1. Base16 Theme
  {
    "RRethy/base16-nvim",
    lazy = false,
    priority = 1000,
  },

  -- 2. Direnv Integration
  -- Ensures environment changes are immediately refreshed and exposed to LSPs
  {
    "direnv/direnv.vim",
    lazy = false,
  },

  -- 3. LSP Configuration & Support
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      -- Autocompletion Engine & Sources
      "hrsh7th/nvim-cmp",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
    },
    config = function()
      local cmp_lsp = require("cmp_nvim_lsp")
      
      -- Advertise cmp-nvim-lsp capabilities to language servers
      local capabilities = cmp_lsp.default_capabilities()

      -- Setup Language Servers here
      -- Ensure these binaries are installed on your host system (e.g., via Nix or system packages)
      local servers = { "nixd" }
      for _, lsp in ipairs(servers) do
        vim.lsp.enable(lsp)
      end

      -- LSP Global Keymaps
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
      vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover docs" })
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
      vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
      vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
    end,
  },

  -- 4. Completion Engine Configuration
  {
    "hrsh7th/nvim-cmp",
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim-lsp" },
        }, {
          { name = "buffer" },
          { name = "path" },
        }),
      })
    end,
  },

  -- 5. Fuzzy Finder (Telescope)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live Grep" },
    },
  },

  -- 6. Syntax Highlighting (Treesitter)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({
        install = { "lua", "markdown", "rust", "python", "nix" },
        highlight = { enable = true },
      })
    end,
  },
}